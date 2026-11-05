import SwiftUI
import WebKit

struct SchoologyPage: Sendable {
    let title: String
    let body: String
    let baseURL: URL
}

struct SchoologyPageDetailView: View {
    @Environment(AppSession.self) private var session
    let courseID: String
    let pageID: String
    let title: String

    @State private var page: SchoologyPage?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading && page == nil {
                ProgressView("Loading page…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, page == nil {
                ContentUnavailableView(
                    "Unable to load page",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let page {
                VStack(alignment: .leading, spacing: 0) {
                    Text(page.title.isEmpty ? title : page.title)
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                    if page.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView("No page content", systemImage: "doc.text")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        SchoologyPageHTMLView(html: page.body, baseURL: page.baseURL)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .overlay(alignment: .top) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .navigationTitle(title)
        .task(id: "\(courseID):\(pageID)") {
            await loadPage()
        }
        .refreshable {
            await loadPage()
        }
    }

    @MainActor
    private func loadPage() async {
        isLoading = true
        error = nil
        do {
            page = try await session.loadCoursePage(courseID: courseID, pageID: pageID)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

private struct SchoologyPageHTMLView: View {
    let html: String
    let baseURL: URL

    var body: some View {
        SchoologyPageWebContent(html: html, baseURL: baseURL)
    }
}

#if os(iOS)
private struct SchoologyPageWebContent: UIViewRepresentable {
    let html: String
    let baseURL: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        context.coordinator.lastHTML = html
        webView.loadHTMLString(Self.document(html), baseURL: baseURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(Self.document(html), baseURL: baseURL)
    }

    static func document(_ body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=3">
          <meta name="color-scheme" content="light dark">
          <style>
            :root { color-scheme: light dark; }
            body { margin: 16px; font: -apple-system-body; line-height: 1.5; color: CanvasText; background: Canvas; overflow-wrap: anywhere; }
            img, video { max-width: 100%; height: auto; }
            table { max-width: 100%; }
            a { color: LinkText; }
            pre, code { white-space: pre-wrap; overflow-wrap: anywhere; }
            iframe { max-width: 100%; }
          </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML = ""
    }
}
#elseif os(macOS)
private struct SchoologyPageWebContent: NSViewRepresentable {
    let html: String
    let baseURL: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = .clear
        context.coordinator.lastHTML = html
        webView.loadHTMLString(Self.document(html), baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(Self.document(html), baseURL: baseURL)
    }

    static func document(_ body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="color-scheme" content="light dark">
          <style>
            :root { color-scheme: light dark; }
            body { margin: 20px; font: -apple-system-body; line-height: 1.5; color: CanvasText; background: Canvas; overflow-wrap: anywhere; }
            img, video { max-width: 100%; height: auto; }
            table { max-width: 100%; }
            a { color: LinkText; }
            pre, code { white-space: pre-wrap; overflow-wrap: anywhere; }
            iframe { max-width: 100%; }
          </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML = ""
    }
}
#endif
