import Foundation
import AuthenticationServices
import CryptoKit
import Security
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct GoogleCloudProject: Identifiable, Hashable {
    let projectID: String
    let displayName: String
    var id: String { projectID }
}

struct GoogleCloudAccount {
    let email: String
    let projects: [GoogleCloudProject]
    let projectError: String?
}

enum ClassWireGoogleCloudError: LocalizedError {
    case invalidCallback
    case missingRefreshToken
    case invalidProject
    case requestFailed(Int, String)
    case invalidResponse(String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCallback: "Google sign-in returned an invalid callback. Try connecting again."
        case .missingRefreshToken: "Google did not issue a refresh token. Revoke ClassWire in your Google Account security settings, then connect again."
        case .invalidProject: "Choose a valid Google Cloud project ID."
        case .requestFailed(let status, let detail): "Google Cloud request failed (HTTP \(status)): \(detail)"
        case .invalidResponse(let detail): detail
        case .operationFailed(let detail): "Google Cloud could not complete the operation: \(detail)"
        }
    }
}

@MainActor
final class ClassWireGoogleCloudService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = ClassWireGoogleCloudService()

    // Public OAuth client ID for the registered iOS app. Google treats installed-app
    // clients as public clients; no client secret belongs in this application.
    private let clientID = "813096753007-n919j0u9c99rcll1f6cb4knme0oapdru.apps.googleusercontent.com"
    private let callbackScheme = "com.googleusercontent.apps.813096753007-n919j0u9c99rcll1f6cb4knme0oapdru"
    private var activeSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
    }

    func connect() async throws -> GoogleCloudAccount {
        let verifier = try Self.makeVerifier()
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = try Self.makeVerifier()
        let redirectURI = "\(callbackScheme):/oauth2redirect"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email https://www.googleapis.com/auth/cloud-platform"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "include_granted_scopes", value: "true"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let authorizationURL = components.url else {
            throw ClassWireGoogleCloudError.invalidResponse("Could not create Google's authorization URL.")
        }

        let callbackURL = try await authenticate(authorizationURL)
        guard let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let callbackState = callback.queryItems?.first(where: { $0.name == "state" })?.value,
              callbackState == state else {
            throw ClassWireGoogleCloudError.invalidCallback
        }
        if let oauthError = callback.queryItems?.first(where: { $0.name == "error" })?.value {
            throw ClassWireGoogleCloudError.invalidResponse("Google sign-in was not completed: \(oauthError)")
        }
        guard let code = callback.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw ClassWireGoogleCloudError.invalidCallback
        }

        let token = try await postForm(
            "https://oauth2.googleapis.com/token",
            values: [
                "client_id": clientID,
                "code": code,
                "code_verifier": verifier,
                "grant_type": "authorization_code",
                "redirect_uri": redirectURI
            ]
        )
        let accessToken = token["access_token"] as? String ?? ""
        guard !accessToken.isEmpty else {
            throw ClassWireGoogleCloudError.invalidResponse("Google did not return an access token.")
        }
        if let refreshToken = token["refresh_token"] as? String, !refreshToken.isEmpty {
            try ClassWireAIKeychainStore.saveGoogleRefreshToken(refreshToken)
        } else if ClassWireAIKeychainStore.loadGoogleRefreshToken() == nil {
            throw ClassWireGoogleCloudError.missingRefreshToken
        }

        let user = try await googleGET("https://www.googleapis.com/oauth2/v3/userinfo", accessToken: accessToken)
        let email = user["email"] as? String ?? "Google account"
        do {
            let projects = try await listProjects(accessToken: accessToken)
            return GoogleCloudAccount(email: email, projects: projects, projectError: nil)
        } catch {
            // Keep the Google account connected even if project discovery needs
            // an API to be enabled or the account needs additional IAM access.
            return GoogleCloudAccount(email: email, projects: [], projectError: error.localizedDescription)
        }
    }

    func listProjects() async throws -> [GoogleCloudProject] {
        let token = try await refreshedAccessToken()
        return try await listProjects(accessToken: token)
    }

    func createOrReuseGeminiKey(projectID: String) async throws -> String {
        let bytes = Array(projectID.utf8)
        guard (6...30).contains(bytes.count),
              let first = bytes.first, first >= 97, first <= 122,
              let last = bytes.last, (last >= 97 && last <= 122) || (last >= 48 && last <= 57),
              bytes.allSatisfy({ ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || $0 == 45 }) else {
            throw ClassWireGoogleCloudError.invalidProject
        }
        let accessToken = try await refreshedAccessToken()
        for service in ["iam.googleapis.com", "apikeys.googleapis.com", "generativelanguage.googleapis.com"] {
            try await enableService(projectID: projectID, service: service, accessToken: accessToken)
        }

        let serviceAccountEmail = "classwire-gemini@\(projectID).iam.gserviceaccount.com"
        let serviceAccountURL = "https://iam.googleapis.com/v1/projects/\(projectID)/serviceAccounts/\(serviceAccountEmail)"
        do {
            _ = try await googleGET(serviceAccountURL, accessToken: accessToken)
        } catch ClassWireGoogleCloudError.requestFailed(let status, _) where status == 404 {
            var createComponents = URLComponents(string: "https://iam.googleapis.com/v1/projects/\(projectID)/serviceAccounts")!
            createComponents.queryItems = [URLQueryItem(name: "accountId", value: "classwire-gemini")]
            let body: [String: Any] = [
                "serviceAccount": [
                    "displayName": "ClassWire Gemini",
                    "description": "Dedicated service-account identity for this user's ClassWire Gemini authorization key. No service-account private key is created."
                ]
            ]
            do {
                _ = try await googleRequest(createComponents.url!, method: "POST", accessToken: accessToken, body: body)
            } catch ClassWireGoogleCloudError.requestFailed(let createStatus, _) where createStatus == 409 {
                // Another device may have created the account after our initial lookup.
            }
        }

        var accountReady = false
        for attempt in 0..<15 {
            do {
                _ = try await googleGET(serviceAccountURL, accessToken: accessToken)
                accountReady = true
                break
            } catch ClassWireGoogleCloudError.requestFailed(let status, _) where status == 404 && attempt < 14 {
                try await Task.sleep(for: .seconds(2))
            }
        }
        guard accountReady else {
            throw ClassWireGoogleCloudError.operationFailed("Google is still preparing the ClassWire service account. Wait a minute and try again.")
        }

        var existingKeyName: String?
        var keyPageToken: String?
        for _ in 0..<10 {
            var keyListComponents = URLComponents(string: "https://apikeys.googleapis.com/v2/projects/\(projectID)/locations/global/keys")!
            var keyQuery = [URLQueryItem(name: "pageSize", value: "100")]
            if let keyPageToken { keyQuery.append(URLQueryItem(name: "pageToken", value: keyPageToken)) }
            keyListComponents.queryItems = keyQuery
            let keyList = try await googleGET(keyListComponents.url!.absoluteString, accessToken: accessToken)
            let existing = (keyList["keys"] as? [[String: Any]] ?? []).first { key in
                let sameAccount = key["serviceAccountEmail"] as? String == serviceAccountEmail
                let targets = (key["restrictions"] as? [String: Any])?["apiTargets"] as? [[String: Any]] ?? []
                let geminiOnly = targets.count == 1 && targets.first?["service"] as? String == "generativelanguage.googleapis.com"
                return sameAccount && geminiOnly
            }
            if let name = existing?["name"] as? String {
                existingKeyName = name
                break
            }
            keyPageToken = keyList["nextPageToken"] as? String
            if keyPageToken == nil || keyPageToken?.isEmpty == true { break }
        }

        let keyResourceName: String
        if let name = existingKeyName {
            keyResourceName = name
        } else {
            let createURL = URL(string: "https://apikeys.googleapis.com/v2/projects/\(projectID)/locations/global/keys")!
            var operation: [String: Any]?
            var lastBindingError: Error?

            // IAM can report the new service account as ready before the API Keys
            // service has propagated it to its service-account binding backend.
            // Give that backend a short head start, then retry only this transient error.
            for attempt in 0..<5 {
                if attempt > 0 {
                    try await Task.sleep(for: .seconds(Double(5 * (1 << (attempt - 1)))))
                    _ = try await googleGET(serviceAccountURL, accessToken: accessToken)
                }
                do {
                    operation = try await googleRequest(
                        createURL,
                        method: "POST",
                        accessToken: accessToken,
                        body: [
                            "displayName": "ClassWire Gemini authorization key",
                            "serviceAccountEmail": serviceAccountEmail,
                            "restrictions": ["apiTargets": [["service": "generativelanguage.googleapis.com"]]]
                        ]
                    )
                    break
                } catch ClassWireGoogleCloudError.requestFailed(let status, let detail)
                    where detail.localizedCaseInsensitiveContains("service account")
                        && detail.localizedCaseInsensitiveContains("not found") {
                    lastBindingError = ClassWireGoogleCloudError.requestFailed(status, detail)
                    if attempt == 2 { throw ClassWireGoogleCloudError.requestFailed(status, detail) }
                }
            }

            guard let operation, let operationName = operation["name"] as? String else {
                if let lastBindingError { throw lastBindingError }
                throw ClassWireGoogleCloudError.invalidResponse("Google did not return the Gemini key-creation operation.")
            }
            let created = try await waitForOperation(
                baseURL: "https://apikeys.googleapis.com/v2",
                operation: operationName,
                accessToken: accessToken
            )
            guard let name = created["name"] as? String else {
                throw ClassWireGoogleCloudError.invalidResponse("Google created the key but did not return its resource name.")
            }
            keyResourceName = name
        }

        let keyResult = try await googleGET("https://apikeys.googleapis.com/v2/\(keyResourceName)/keyString", accessToken: accessToken)
        guard let key = keyResult["keyString"] as? String, key.count >= 8 else {
            throw ClassWireGoogleCloudError.invalidResponse("Google did not return the Gemini API key string.")
        }
        return key
    }

    private func authenticate(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let completionHandler: (URL?, Error?) -> Void = { callbackURL, error in
                Task { @MainActor in
                    self.activeSession = nil
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else {
                        continuation.resume(throwing: ClassWireGoogleCloudError.invalidCallback)
                    }
                }
            }
            let session: ASWebAuthenticationSession
            #if os(macOS)
            if #available(macOS 14.4, *) {
                session = ASWebAuthenticationSession(
                    url: url,
                    callback: .customScheme(callbackScheme),
                    completionHandler: completionHandler
                )
            } else {
                session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: callbackScheme,
                    completionHandler: completionHandler
                )
            }
            #else
            session = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme(callbackScheme),
                completionHandler: completionHandler
            )
            #endif
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session
            if !session.start() {
                activeSession = nil
                continuation.resume(throwing: ClassWireGoogleCloudError.invalidResponse("Could not start Google's secure sign-in session."))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? UIWindow()
        #elseif os(macOS)
        return NSApp.keyWindow ?? NSApp.mainWindow ?? NSWindow()
        #endif
    }

    private func refreshedAccessToken() async throws -> String {
        guard let refreshToken = ClassWireAIKeychainStore.loadGoogleRefreshToken() else {
            throw ClassWireGoogleCloudError.invalidResponse("Connect your Google account before managing Gemini API keys.")
        }
        let token = try await postForm(
            "https://oauth2.googleapis.com/token",
            values: [
                "client_id": clientID,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token"
            ]
        )
        guard let accessToken = token["access_token"] as? String, !accessToken.isEmpty else {
            throw ClassWireGoogleCloudError.invalidResponse("Google did not refresh the authorization. Reconnect your account.")
        }
        if let rotated = token["refresh_token"] as? String, !rotated.isEmpty {
            try ClassWireAIKeychainStore.saveGoogleRefreshToken(rotated)
        }
        return accessToken
    }

    private func listProjects(accessToken: String) async throws -> [GoogleCloudProject] {
        var projects: [GoogleCloudProject] = []
        var pageToken: String?
        for _ in 0..<20 {
            var components = URLComponents(string: "https://cloudresourcemanager.googleapis.com/v3/projects:search")!
            var query = [URLQueryItem(name: "pageSize", value: "100")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = query
            let page = try await googleGET(components.url!.absoluteString, accessToken: accessToken)
            for item in page["projects"] as? [[String: Any]] ?? [] {
                guard item["state"] as? String == "ACTIVE",
                      let id = item["projectId"] as? String, !id.isEmpty else { continue }
                projects.append(GoogleCloudProject(projectID: id, displayName: item["displayName"] as? String ?? id))
            }
            pageToken = page["nextPageToken"] as? String
            if pageToken == nil || pageToken?.isEmpty == true { break }
        }
        return projects.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func enableService(projectID: String, service: String, accessToken: String) async throws {
        let escaped = service.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? service
        let base = "https://serviceusage.googleapis.com/v1/projects/\(projectID)/services/\(escaped)"
        let current = try await googleGET(base, accessToken: accessToken)
        if current["state"] as? String == "ENABLED" { return }
        let operation = try await googleRequest(URL(string: base + ":enable")!, method: "POST", accessToken: accessToken, body: nil)
        if let name = operation["name"] as? String {
            _ = try await waitForOperation(baseURL: "https://serviceusage.googleapis.com/v1", operation: name, accessToken: accessToken)
        }
    }

    private func waitForOperation(baseURL: String, operation: String, accessToken: String) async throws -> [String: Any] {
        let url = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + operation.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        for attempt in 0..<90 {
            let result = try await googleGET(url, accessToken: accessToken)
            if result["done"] as? Bool == true {
                if let error = result["error"] {
                    throw ClassWireGoogleCloudError.operationFailed(String(describing: error))
                }
                return result["response"] as? [String: Any] ?? result
            }
            if attempt < 89 { try await Task.sleep(for: .seconds(1)) }
        }
        throw ClassWireGoogleCloudError.operationFailed("The request is still processing. Wait a moment and try again.")
    }

    private func googleGET(_ string: String, accessToken: String) async throws -> [String: Any] {
        guard let url = URL(string: string) else {
            throw ClassWireGoogleCloudError.invalidResponse("Google returned an invalid API URL.")
        }
        return try await googleRequest(url, method: "GET", accessToken: accessToken, body: nil)
    }

    private func googleRequest(_ url: URL, method: String, accessToken: String, body: [String: Any]?) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClassWireGoogleCloudError.invalidResponse("Google Cloud returned an invalid HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let error = root?["error"] as? [String: Any]
            let detail = error?["message"] as? String ?? String(decoding: data.prefix(900), as: UTF8.self)
            throw ClassWireGoogleCloudError.requestFailed(http.statusCode, detail)
        }
        if data.isEmpty { return [:] }
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClassWireGoogleCloudError.invalidResponse("Google Cloud returned invalid JSON.")
        }
        return result
    }

    private func postForm(_ urlString: String, values: [String: String]) async throws -> [String: Any] {
        var components = URLComponents()
        components.queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = URL(string: urlString), let body = components.percentEncodedQuery?.data(using: .utf8) else {
            throw ClassWireGoogleCloudError.invalidResponse("Could not create Google's token request.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClassWireGoogleCloudError.invalidResponse("Google returned an invalid token response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let detail = (root?["error_description"] as? String) ?? (root?["error"] as? String) ?? "Authorization was rejected."
            throw ClassWireGoogleCloudError.requestFailed(http.statusCode, detail)
        }
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClassWireGoogleCloudError.invalidResponse("Google returned invalid token JSON.")
        }
        return result
    }

    private static func makeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw ClassWireGoogleCloudError.invalidResponse("Could not create secure OAuth state.")
        }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
