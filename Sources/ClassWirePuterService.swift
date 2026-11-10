import Foundation
import Observation
import SwiftUI
import WebKit

@MainActor
@Observable
final class ClassWirePuterService: NSObject, WKUIDelegate, WKNavigationDelegate {
    struct ToolCall { let name: String; let arguments: [String: Any] }
    struct ChatResult { let text: String; let toolCalls: [ToolCall] }

    static let shared = ClassWirePuterService()
    private(set) var isSignedIn = false
    private(set) var accountLabel = ""
    private(set) var isSigningIn = false
    private(set) var signInError: String?
    var isPopupPresented = false

    @ObservationIgnored private(set) var webView: WKWebView!
    @ObservationIgnored private(set) var popupWebView: WKWebView?
    @ObservationIgnored private var scriptHandler: ClassWirePuterScriptHandler!
    @ObservationIgnored private var isReady = false
    @ObservationIgnored private var loadError: String?
    @ObservationIgnored private var pending: [String: CheckedContinuation<Data, Error>] = [:]
    @ObservationIgnored private var pendingTimeouts: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var readyWaiters: [CheckedContinuation<Void, Error>] = []

    private override init() {
        super.init()
        let controller = WKUserContentController()
        scriptHandler = ClassWirePuterScriptHandler(service: self)
        controller.add(scriptHandler, name: "classWirePuter")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.loadHTMLString(Self.bridgeHTML, baseURL: URL(string: "http://localhost"))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        isReady = true
        loadError = nil
        readyWaiters.forEach { $0.resume() }
        readyWaiters.removeAll()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failReadyWaiters(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failReadyWaiters(error) }

    private func failReadyWaiters(_ error: Error) {
        loadError = error.localizedDescription
        readyWaiters.forEach { $0.resume(throwing: error) }
        readyWaiters.removeAll()
    }

    func receive(_ message: WKScriptMessage) {
        guard message.name == "classWirePuter", message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "http",
              message.frameInfo.securityOrigin.host == "localhost",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        if type == "auth" {
            isSignedIn = body["signedIn"] as? Bool ?? false
            accountLabel = body["user"] as? String ?? ""
            return
        }
        guard let id = body["id"] as? String, let continuation = pending.removeValue(forKey: id) else { return }
        pendingTimeouts.removeValue(forKey: id)?.cancel()
        if let error = body["error"] as? String {
            continuation.resume(throwing: ClassWireAIError.invalidResponse(error))
        } else {
            let result = body["result"] ?? NSNull()
            do {
                let data = try JSONSerialization.data(
                    withJSONObject: result,
                    options: [.fragmentsAllowed, .sortedKeys]
                )
                continuation.resume(returning: data)
            } catch {
                continuation.resume(
                    throwing: ClassWireAIError.invalidResponse("Puter returned a response that could not be decoded.")
                )
            }
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.uiDelegate = self
        popup.navigationDelegate = self
        popupWebView = popup
        isPopupPresented = true
        return popup
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        let scheme = url?.scheme?.lowercased()
        let isLocalBridge = scheme == "http" && url?.host == "localhost"
        decisionHandler((scheme == "https" || scheme == "about" || isLocalBridge) ? .allow : .cancel)
    }

    func webViewDidClose(_ webView: WKWebView) {
        if webView === popupWebView {
            popupWebView = nil
            isPopupPresented = false
        }
    }

    func refreshAuthStatus() async {
        guard isReady else { return }
        do {
            let value = try await request("status")
            guard let status = value as? [String: Any] else { return }
            isSignedIn = status["signedIn"] as? Bool ?? false
            accountLabel = status["user"] as? String ?? ""
        } catch { }
    }

    func listModels() async throws -> [String] {
        guard let models = try await request("models") as? [String] else {
            throw ClassWireAIError.invalidResponse("Puter returned an invalid model catalogue.")
        }
        return models
    }

    func chat(model: String, messages: [ClassWireAIMessage], tools: [[String: Any]], systemPrompt: String) async throws -> ChatResult {
        let declarations: [[String: Any]] = tools.compactMap { tool in
            guard let name = tool["name"] as? String else { return nil }
            return ["type": "function", "function": [
                "name": name, "description": tool["description"] as? String ?? "",
                "parameters": tool["parameters"] ?? ["type": "object", "properties": [:]]
            ]]
        }
        let payload: [String: Any] = [
            "model": model,
            "messages": [["role": "system", "content": systemPrompt]] + messages.map { ["role": $0.role, "content": $0.content] },
            "tools": declarations,
            "toolChoice": "auto"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        guard let result = try await request("chat", payload: data.base64EncodedString()) as? [String: Any] else {
            throw ClassWireAIError.invalidResponse("Puter returned an invalid chat response.")
        }
        let calls = (result["toolCalls"] as? [[String: Any]] ?? []).compactMap { item -> ToolCall? in
            guard let name = item["name"] as? String else { return nil }
            let arguments: [String: Any]
            if let object = item["arguments"] as? [String: Any] { arguments = object }
            else if let raw = item["arguments"] as? String, let data = raw.data(using: .utf8),
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { arguments = object }
            else { arguments = [:] }
            return ToolCall(name: name, arguments: arguments)
        }
        return ChatResult(text: result["text"] as? String ?? "", toolCalls: calls)
    }

    func signIn() async {
        isSigningIn = true
        signInError = nil
        defer { isSigningIn = false }

        do {
            _ = try await request("signIn")
        } catch {
            signInError = error.localizedDescription
        }
    }

    func signOut() async {
        do { _ = try await request("signOut") }
        catch { isSignedIn = false; accountLabel = "" }
    }

    func closePopup() {
        popupWebView?.stopLoading()
        popupWebView?.uiDelegate = nil
        popupWebView?.navigationDelegate = nil
        popupWebView = nil
        isPopupPresented = false
    }

    private func request(_ operation: String, payload: String? = nil) async throws -> Any {
        try await waitUntilReady()
        let responseData: Data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let id = UUID().uuidString
            pending[id] = continuation
            if operation == "models" {
                pendingTimeouts[id] = Task { [weak self] in
                    do {
                        try await Task.sleep(for: .seconds(70))
                        guard let self, let pending = self.pending.removeValue(forKey: id) else { return }
                        self.pendingTimeouts.removeValue(forKey: id)
                        pending.resume(throwing: ClassWireAIError.invalidResponse("Puter did not respond to the model catalogue request within 70 seconds. Check your connection and try refreshing the model list."))
                    } catch { }
                }
            }
            let encodedPayload = payload.map(Self.jsString) ?? "null"
            let script = "(() => { void window.classWirePuterRequest(\(Self.jsString(id)), \(Self.jsString(operation)), \(encodedPayload)); return true; })();"
            webView.evaluateJavaScript(script) { _, error in
                if let error, let pending = self.pending.removeValue(forKey: id) {
                    self.pendingTimeouts.removeValue(forKey: id)?.cancel()
                    pending.resume(throwing: error)
                }
            }
        }
        return try JSONSerialization.jsonObject(with: responseData, options: [.fragmentsAllowed])
    }

    private func waitUntilReady() async throws {
        if isReady { return }
        if let loadError { throw ClassWireAIError.invalidResponse("Puter could not load: \(loadError)") }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in readyWaiters.append(continuation) }
    }

    private static func jsString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return encoded
    }

    private static let bridgeHTML = """
    <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
    <style>:root{color-scheme:light dark;font:-apple-system-body}body{margin:0;padding:24px;background:transparent;color:CanvasText}
    main{max-width:520px;margin:0 auto}h1{font-size:22px;margin:0 0 8px}p,#status{color:GrayText;line-height:1.45}
    button{font:inherit;font-weight:600;border:0;border-radius:12px;padding:13px 18px;min-height:48px;background:#1769aa;color:white;width:100%}
    button:disabled{opacity:.55}</style></head><body><main><h1>Connect Puter</h1>
    <p>Sign in to Puter to use its AI models. Puter securely manages your account session.</p>
    <button id="connect" disabled>Loading Puter…</button><div id="status" role="status" aria-live="polite">Loading authentication…</div></main>
    <script src="https://js.puter.com/v2/"></script><script>
    (()=>{const button=document.getElementById('connect'),status=document.getElementById('status');
    const send=value=>window.webkit.messageHandlers.classWirePuter.postMessage(value);
    const userLabel=user=>user?.username||user?.email||user?.name||'Puter account';
    let resolveReady;window.classWirePuterReady=new Promise(resolve=>{resolveReady=resolve;});
    const report=async()=>{try{const signedIn=!!puter.auth.isSignedIn(),user=signedIn?await puter.auth.getUser():null;
      send({type:'auth',signedIn,user:user?userLabel(user):''});button.textContent=signedIn?'Connected to Puter':'Connect with Puter';
      status.textContent=signedIn?'Your Puter account is connected.':'Sign in to continue.';button.disabled=false;
    }catch(error){status.textContent=String(error?.message||error);button.disabled=false;}};
    window.classWirePuterRequest=async(id,operation,payload)=>{try{await window.classWirePuterReady;
      if(operation==='status'){const signedIn=!!puter.auth.isSignedIn(),user=signedIn?await puter.auth.getUser():null;
        send({type:'auth',signedIn,user:user?userLabel(user):''});send({id,result:{signedIn,user:user?userLabel(user):''}});return;}
      if(operation==='signIn'){await puter.auth.signIn({request_auth:true});await report();send({id,result:true});return;}
      if(operation==='signOut'){await puter.auth.signOut();await report();send({id,result:true});return;}
      if(!puter.auth.isSignedIn())throw new Error('Connect your Puter account first.');
      let result;
      if(operation==='models'){
        // Match the working Tauri client and Puter.js's documented all-provider call.
        const catalogue=await new Promise((resolve,reject)=>{
          const timer=setTimeout(()=>reject(new Error('Puter model catalogue request timed out after 60 seconds.')),60000);
          Promise.resolve(puter.ai.listModels()).then(value=>{clearTimeout(timer);resolve(value);},error=>{clearTimeout(timer);reject(error);});
        });
        if(!Array.isArray(catalogue))throw new Error('Puter returned an invalid model catalogue response.');
        result=[...new Set(catalogue.map(item=>typeof item==='string'?item:item?.id)
          .filter(id=>typeof id==='string'&&id.length>0))].sort();
        if(!result.length)throw new Error('Puter returned an empty model catalogue. Check that your Puter account can access AI models.');
      }
      else if(operation==='chat'){const raw=atob(payload),bytes=Uint8Array.from(raw,c=>c.charCodeAt(0)),request=JSON.parse(new TextDecoder().decode(bytes));
        const response=await puter.ai.chat(request.messages,{model:request.model,tools:request.tools,toolChoice:'auto',normalize:true});
        const message=response?.message||response;let content=message?.content??'';
        if(Array.isArray(content))content=content.map(part=>part?.text||'').filter(Boolean).join('\\n');
        const toolCalls=(message?.tool_calls||message?.toolCalls||[]).map(call=>{let args=call?.function?.arguments??call?.arguments??{};
          if(typeof args==='string'){try{args=JSON.parse(args);}catch(_){args={};}}
          return {name:call?.function?.name||call?.name,arguments:args};}).filter(call=>typeof call.name==='string');
        result={text:typeof content==='string'?content:'',toolCalls};}
      else throw new Error('Unsupported Puter operation.');
      send({id,result});
    }catch(error){send({id,error:String(error?.message||error)});}};
    button.addEventListener('click',async()=>{button.disabled=true;status.textContent='Opening Puter sign-in…';
      try{await puter.auth.signIn({request_auth:true});await report();}
      catch(error){status.textContent=String(error?.message||error);button.disabled=false;}});
    const poll=setInterval(()=>{if(window.puter){clearInterval(poll);resolveReady();report();}},100);
    setTimeout(()=>{clearInterval(poll);if(!window.puter)status.textContent='Puter could not load. Check your internet connection.';},15000);
    })();
    </script></body></html>
    """
}

@MainActor
private final class ClassWirePuterScriptHandler: NSObject, WKScriptMessageHandler {
    weak var service: ClassWirePuterService?
    init(service: ClassWirePuterService) { self.service = service }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        service?.receive(message)
    }
}

#if os(iOS)
struct ClassWirePuterWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
#elseif os(macOS)
struct ClassWirePuterWebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
#endif

struct ClassWirePuterConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var service: ClassWirePuterService

    var body: some View {
        NavigationStack {
            Group {
                if service.isPopupPresented, let popup = service.popupWebView {
                    ClassWirePuterWebView(webView: popup)
                } else if let error = service.signInError {
                    ContentUnavailableView {
                        Label("Couldn’t open Puter sign-in", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await service.signIn() }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Opening Puter sign-in…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .navigationTitle("Sign in to Puter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        service.closePopup()
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 320, minHeight: 360)
    }
}
