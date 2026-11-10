import Foundation
import CryptoKit

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

enum SchoologyAPIError: LocalizedError {
    case invalidResponse
    case http(Int, String)
    case attachment(String)
    case invalidToken
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "ClassWire returned an invalid response."
        case .http(let code, let detail): "ClassWire request failed (HTTP \(code)): \(detail)"
        case .attachment(let detail): detail
        case .invalidToken: "ClassWire did not return a valid access token."
        case .notSignedIn: "Please sign in to ClassWire."
        }
    }
}

actor SchoologyAPI {
    static let shared = SchoologyAPI()
    private var consumerKey: String { useCanadianServer ? ["89b659ae6f6631f1", "0b0bd7a513aab9fb", "04bfb014f"].joined() : ["998121f221d5dc0f", "4956ee6946d27d5e", "04e55635e"].joined() }
    private var consumerSecret: String { useCanadianServer ? ["7ab6b83e0c89bec7", "1010582da6e82ed9"].joined() : ["5cff9d3780d64695", "d762ba8e05a34e9e"].joined() }
    private let mobileCookie = "s_mobile=03447c0175ac0c7299a5508fde9569fc"
    private let userAgent = "okhttp/4.8.0"
    private var timeOffset: Int64 = 0
    private var lastServerTimeSync: Date?
    private var recentOAuthNonces = Set<String>()
    private var oauthNonceOrder: [String] = []
    private var oauthNonceCounter: UInt64 = 0
    private var useCanadianServer = false
    private let imageDataCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 120
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()
    func setCanadianServer(_ enabled: Bool) {
        guard useCanadianServer != enabled else { return }
        useCanadianServer = enabled
        // The server-time offset is host-specific; force a fresh sync after switching regions.
        lastServerTimeSync = nil
    }

    private var apiHost: String { useCanadianServer ? "api.schoologyca.com" : "api.schoology.com" }
    private var webHost: String { useCanadianServer ? "app.schoologyca.com" : "app.schoology.com" }

    func searchSchools(_ query: String) async throws -> [SchoologySchool] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var components = URLComponents()
        components.scheme = "https"
        components.host = apiHost
        components.path = "/v1/login/school_search"
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        guard let url = components.url else { throw SchoologyAPIError.invalidResponse }
        let data = try await send(url: url, method: "GET", body: nil, auth: nil, signed: false, extra: [])
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["school"] as? [[String: Any]] ?? []).compactMap(SchoologySchool.init)
    }

    func login(username: String, password: String, schoolID: String?) async throws -> SchoologyAuth {
        await syncServerTime()
        let temporary = try await requestToken()
        var fields = [
            "user": username,
            "password": password,
            "oauth_token": temporary.token
        ]
        if let schoolID, !schoolID.isEmpty { fields["school_id"] = schoolID }
        let url = URL(string: "https://\(webHost)/oauth/authorize_auto")!
        let body = formEncode(fields)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Android", forHTTPHeaderField: "X-Schoology-Client")
        request.setValue("2026.10.0", forHTTPHeaderField: "X-Schoology-App-Version")
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        let access = try await exchangeToken(temporary)
        return access
    }

    func loginWithQRCode(_ qrCode: String) async throws -> SchoologyAuth {
        let payload = qrCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { throw SchoologyAPIError.invalidResponse }
        await syncServerTime()
        let temporary = try await requestToken()
        // Match login_qr() in the official Tauri 2026.10.0-port.28 source.
        // This endpoint is rooted at /oauth, not /v1/oauth.
        let url = URL(string: "https://\(apiHost)/oauth/qr_code_authorize_auto")!
        let body = formEncode([
            "scanned_qr_data": payload,
            "oauth_token": temporary.token
        ])
        _ = try await send(
            url: url,
            method: "POST",
            body: body,
            auth: temporary,
            signed: true,
            extra: [("scanned_qr_data", oauthEncode(payload))]
        )
        return try await exchangeToken(temporary)
    }

    func prepareSchoolBrowserLogin(domain: String) async throws -> SchoologyPendingSchoolLogin {
        let rawDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawDomain.isEmpty,
              let parsed = URL(string: rawDomain.contains("://") ? rawDomain : "https://\(rawDomain)"),
              ["http", "https"].contains(parsed.scheme?.lowercased() ?? ""),
              parsed.user == nil,
              parsed.password == nil,
              let host = parsed.host, !host.isEmpty else {
            throw SchoologyAPIError.invalidResponse
        }

        await syncServerTime()
        let temporary = try await requestToken()
        guard !temporary.token.isEmpty, !temporary.secret.isEmpty else {
            throw SchoologyAPIError.invalidToken
        }

        // Match LoginOAuthManagementActivity.R0() from the official Tauri port.
        let callback = "https://\(host)/mobile_login_success?os=android&os_version=34&app_version=600000478"
        let oauthPath = "oauth/authorize?oauth_token=\(temporary.token)&oauth_callback=\(androidURIEncode(callback))"
        let authorizationString = "https://\(host)/\(oauthPath)&login_landing_dest=\(androidURIEncode(oauthPath))"
        guard let authorizationURL = URL(string: authorizationString),
              authorizationURL.scheme == "https",
              authorizationURL.host == host else {
            throw SchoologyAPIError.invalidResponse
        }
        return SchoologyPendingSchoolLogin(credential: temporary, authorizationURL: authorizationURL)
    }

    func completeSchoolBrowserLogin(
        _ pending: SchoologyPendingSchoolLogin,
        callbackURL: URL
    ) async throws -> SchoologyAuth {
        let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let callbackToken = queryItems.first {
            ($0.name == "request_token" || $0.name == "oauth_token") && !($0.value ?? "").isEmpty
        }?.value
        guard callbackURL.scheme?.lowercased() == "schoology",
              callbackURL.host?.lowercased() == "external_login_callback",
              callbackToken == pending.credential.token else {
            throw SchoologyAPIError.invalidToken
        }

        // Exchange only the request token created for this browser session.
        // exchangeToken() verifies /v1/users/me before returning credentials.
        return try await exchangeToken(pending.credential)
    }

    private func androidURIEncode(_ value: String) -> String {
        // Matches url::form_urlencoded::byte_serialize() in the Tauri port.
        var encoded = ""
        for byte in value.utf8 {
            switch byte {
            case 65...90, 97...122, 48...57, 45, 46, 95, 42:
                encoded += String(decoding: [byte], as: UTF8.self)
            case 32:
                encoded.append("+")
            default:
                encoded += String(format: "%%%02X", byte)
            }
        }
        return encoded
    }

    func currentUser(auth: SchoologyAuth) async throws -> SchoologyUser {
        let data = try await get("users/me", auth: auth)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] else { throw SchoologyAPIError.invalidResponse }
        return SchoologyUser(
            id: String(describing: id),
            nameDisplay: json["name_display"] as? String ?? json["name"] as? String ?? "ClassWire user",
            pictureURL: URL(string: json["picture_url"] as? String ?? "")
        )
    }

    func webSessionCookies(auth: SchoologyAuth) async throws -> [SchoologyWebCookie] {
        await syncServerTime()
        var components = URLComponents(string: "https://\(apiHost)/v1/sessionstart")!
        components.queryItems = [URLQueryItem(name: "for_domain", value: webHost)]
        guard let url = components.url else { throw SchoologyAPIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 45
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Android", forHTTPHeaderField: "X-Schoology-Client")
        request.setValue("2026.10.0", forHTTPHeaderField: "X-Schoology-App-Version")
        request.setValue(mobileCookie, forHTTPHeaderField: "Cookie")
        request.setValue(try authorization(method: "GET", url: url, auth: auth, extra: []), forHTTPHeaderField: "Authorization")
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request, delegate: NoRedirectDelegate())
        try validate(response, data: data)
        guard let http = response as? HTTPURLResponse else { throw SchoologyAPIError.invalidResponse }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let cookieDomain = useCanadianServer ? ".schoologyca.com" : ".schoology.com"
        let rawCookies = (json["cookie"] as? [[String: Any]]) ?? (json["cookies"] as? [[String: Any]]) ?? []
        var cookies: [SchoologyWebCookie] = rawCookies.compactMap { raw in
            let name = SchoologyValue.string(raw["key"] ?? raw["name"])
            let value = SchoologyValue.string(raw["value"] ?? raw["val"])
            guard !name.isEmpty && !value.isEmpty else { return nil }
            return SchoologyWebCookie(name: name, value: value, domain: SchoologyValue.string(raw["domain"], fallback: cookieDomain), path: SchoologyValue.string(raw["path"], fallback: "/"))
        }
        let headerFields = Dictionary(uniqueKeysWithValues: http.allHeaderFields.map { (String(describing: $0.key), String(describing: $0.value)) })
        for cookie in HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url) {
            if !cookies.contains(where: { $0.name == cookie.name }) {
                cookies.append(SchoologyWebCookie(name: cookie.name, value: cookie.value, domain: cookie.domain, path: cookie.path))
            }
        }
        if !cookies.contains(where: { $0.name == "s_mobile" }) {
            let mobileValue = mobileCookie.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
            cookies.append(SchoologyWebCookie(name: "s_mobile", value: mobileValue, domain: cookieDomain, path: "/"))
        }
        let suffix = useCanadianServer ? "schoologyca.com" : "schoology.com"
        let safe = cookies.filter {
            let domain = $0.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return !$0.name.isEmpty && !$0.value.isEmpty &&
                (domain == suffix || domain.hasSuffix(".\(suffix)")) &&
                !$0.name.contains(";") && !$0.value.contains(";")
        }
        guard safe.contains(where: { $0.name.uppercased().hasPrefix("SESS") }) else {
            throw SchoologyAPIError.invalidToken
        }
        return safe
    }

    func get(_ path: String, auth: SchoologyAuth, params: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(string: "https://\(apiHost)/v1/\(path)")!
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw SchoologyAPIError.invalidResponse }
        return try await send(url: url, method: "GET", body: nil, auth: auth, signed: true, extra: [])
    }

    func getV2(_ path: String, auth: SchoologyAuth, params: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(string: "https://\(apiHost)/v2/\(path)")!
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw SchoologyAPIError.invalidResponse }
        return try await send(url: url, method: "GET", body: nil, auth: auth, signed: true, extra: [])
    }

    func launchCourseApp(_ launchLink: URL, sectionID: String, auth: SchoologyAuth) async throws -> URL {
        let apiBase = URL(string: "https://\(apiHost)")!
        let url = URL(string: launchLink.absoluteString, relativeTo: apiBase)?.absoluteURL ?? launchLink
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.caseInsensitiveCompare(apiHost) == .orderedSame,
              components.user == nil, components.password == nil, components.port == nil else {
            throw SchoologyAPIError.invalidResponse
        }
        let path = components.path.split(separator: "/")
        guard path.count == 6, path[0] == "v2", path[1] == "sections",
              String(path[2]) == sectionID, path[3] == "applications",
              Int(path[4]) != nil, path[5] == "launch" else {
            throw SchoologyAPIError.invalidResponse
        }
        let data = try await send(url: url, method: "GET", body: nil, auth: auth, signed: true, extra: [])
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let payload = (json["data"] as? [String: Any]) ?? (json["response"] as? [String: Any]) ?? json
        guard let rawURL = payload["url"] as? String, let destination = URL(string: rawURL),
              let target = URLComponents(url: destination, resolvingAgainstBaseURL: false),
              target.scheme?.lowercased() == "https", target.host != nil,
              target.user == nil, target.password == nil else {
            throw SchoologyAPIError.invalidResponse
        }
        return destination
    }


    func launchResourceApp(appID: String, auth: SchoologyAuth) async throws -> URL {
        guard Int(appID) != nil else { throw SchoologyAPIError.invalidResponse }
        let data = try await getV2("resources/applications/\(appID)/launch", auth: auth)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let payload = (json["data"] as? [String: Any]) ?? (json["response"] as? [String: Any]) ?? json
        guard let rawURL = payload["url"] as? String, let destination = URL(string: rawURL),
              let target = URLComponents(url: destination, resolvingAgainstBaseURL: false),
              target.scheme?.lowercased() == "https", target.host != nil,
              target.user == nil, target.password == nil else {
            throw SchoologyAPIError.invalidResponse
        }
        return destination
    }

    func importResourceApp(url: URL, auth: SchoologyAuth, cookies: [SchoologyWebCookie]) async throws -> [SchoologyPickedResource] {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.caseInsensitiveCompare(webHost) == .orderedSame,
              components.path.contains("/content_app/import"),
              components.user == nil, components.password == nil else {
            throw SchoologyAPIError.invalidResponse
        }
        if !(components.queryItems ?? []).contains(where: { $0.name == "mobile" }) {
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "mobile", value: "1")]
        }
        guard let importURL = components.url else { throw SchoologyAPIError.invalidResponse }
        await syncServerTime()
        let validCookies = cookies.filter { cookie in
            let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
            return webHost.lowercased() == domain || webHost.lowercased().hasSuffix("." + domain)
        }
        let cookieHeader = ([mobileCookie] + validCookies.map { "\($0.name)=\($0.value)" }).joined(separator: "; ")
        let data = try await send(
            url: importURL, method: "GET", body: nil, auth: auth, signed: true, extra: [],
            clientIdentity: false, cookieHeader: cookieHeader
        )
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let payload = (root["data"] as? [String: Any]) ?? (root["response"] as? [String: Any]) ?? root
        let imports = payload["imports"] as? [[String: Any]] ?? []
        var result: [SchoologyPickedResource] = []
        for imported in imports {
            let attachment = imported["attachment"] as? [String: Any] ?? [:]
            let files = attachment["files"] as? [String: Any] ?? [:]
            for file in (files["file"] as? [[String: Any]] ?? []) {
                let id = SchoologyValue.string(file["id"])
                guard !id.isEmpty else { continue }
                result.append(SchoologyPickedResource(
                    id: id, title: SchoologyValue.string(file["title"] ?? file["filename"], fallback: "Imported file")
                ))
            }
            let links = attachment["links"] as? [String: Any] ?? [:]
            for link in (links["link"] as? [[String: Any]] ?? []) {
                let id = SchoologyValue.string(link["id"])
                guard !id.isEmpty else { continue }
                result.append(SchoologyPickedResource(
                    id: id, title: SchoologyValue.string(link["title"], fallback: "Imported link")
                ))
            }
        }
        return result
    }

    func post(_ path: String, auth: SchoologyAuth) async throws -> Data {
        try await post(path, auth: auth, params: [:])
    }

    func post(_ path: String, auth: SchoologyAuth, params: [String: String]) async throws -> Data {
        await syncServerTime()
        let url = URL(string: "https://\(apiHost)/v1/\(path)")!
        let body = formEncode(params)
        // Android and Tauri sign URL query parameters and OAuth fields, not form-body fields.
        return try await send(url: url, method: "POST", body: body, auth: auth, signed: true, extra: [])
    }

    func postJSON(_ path: String, auth: SchoologyAuth, params: [String: String] = [:], body: [String: Any]) async throws -> Data {
        await syncServerTime()
        var components = URLComponents(string: "https://\(apiHost)/v1/\(path)")!
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url, JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]),
              let payload = String(data: data, encoding: .utf8) else { throw SchoologyAPIError.invalidResponse }
        return try await send(url: url, method: "POST", body: payload, auth: auth, signed: true, extra: [], contentType: "application/json")
    }

    func postJSONData(_ path: String, auth: SchoologyAuth, params: [String: String] = [:], bodyData: Data) async throws -> Data {
        await syncServerTime()
        var components = URLComponents(string: "https://\(apiHost)/v1/\(path)")!
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url,
              let object = try? JSONSerialization.jsonObject(with: bodyData),
              JSONSerialization.isValidJSONObject(object),
              let payload = String(data: bodyData, encoding: .utf8) else { throw SchoologyAPIError.invalidResponse }
        return try await send(url: url, method: "POST", body: payload, auth: auth, signed: true, extra: [], contentType: "application/json")
    }

    func putJSONData(_ path: String, auth: SchoologyAuth, params: [String: String] = [:], bodyData: Data) async throws -> Data {
        await syncServerTime()
        var components = URLComponents(string: "https://\(apiHost)/v1/\(path)")!
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url,
              let object = try? JSONSerialization.jsonObject(with: bodyData),
              JSONSerialization.isValidJSONObject(object),
              let payload = String(data: bodyData, encoding: .utf8) else { throw SchoologyAPIError.invalidResponse }
        return try await send(url: url, method: "PUT", body: payload, auth: auth, signed: true, extra: [], contentType: "application/json")
    }

    func putJSON(_ path: String, auth: SchoologyAuth, params: [String: String] = [:], body: [String: Any]) async throws -> Data {
        await syncServerTime()
        var components = URLComponents(string: "https://\(apiHost)/v1/\(path)")!
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url, JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]),
              let payload = String(data: data, encoding: .utf8) else { throw SchoologyAPIError.invalidResponse }
        return try await send(url: url, method: "PUT", body: payload, auth: auth, signed: true, extra: [], contentType: "application/json")
    }


    func delete(_ path: String, auth: SchoologyAuth) async throws -> Data {
        let url = URL(string: "https://\(apiHost)/v1/\(path)")!
        return try await send(url: url, method: "DELETE", body: nil, auth: auth, signed: true, extra: [])
    }

    func postMultiOptions(_ paths: [String], auth: SchoologyAuth) async throws -> Data {
        try await postJSON("multioptions", auth: auth, body: ["request": paths])
    }

    func imageData(_ url: URL, auth: SchoologyAuth) async throws -> Data? {
        guard url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http" else { return nil }
        let cacheKey = "\(auth.userID)|\(apiHost)|\(url.absoluteString)" as NSString
        if let cached = imageDataCache.object(forKey: cacheKey) {
            return cached as Data
        }
        await syncServerTime()
        let session = URLSession(configuration: .ephemeral)
        let redirectDelegate = NoRedirectDelegate()
        defer { session.invalidateAndCancel() }

        var currentURL = url
        for redirectCount in 0...5 {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 20
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("https://\(webHost)/", forHTTPHeaderField: "Referer")
            let requestHost = currentURL.host?.lowercased() ?? ""
            let schoologyDomain = useCanadianServer ? "schoologyca.com" : "schoology.com"
            if requestHost == schoologyDomain || requestHost.hasSuffix("." + schoologyDomain) {
                request.setValue(mobileCookie, forHTTPHeaderField: "Cookie")
            }
            if requestHost == apiHost.lowercased() {
                request.setValue("Android", forHTTPHeaderField: "X-Schoology-Client")
                request.setValue("2026.10.0", forHTTPHeaderField: "X-Schoology-App-Version")
                request.setValue(try authorization(method: "GET", url: currentURL, auth: auth, extra: []), forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await session.data(for: request, delegate: redirectDelegate)
            guard let http = response as? HTTPURLResponse else { throw SchoologyAPIError.invalidResponse }
            if (300...399).contains(http.statusCode),
               redirectCount < 5,
               let location = http.value(forHTTPHeaderField: "Location"),
               let nextURL = URL(string: location, relativeTo: currentURL)?.absoluteURL,
               nextURL.scheme?.lowercased() == "https" {
                currentURL = nextURL
                continue
            }
            guard (200..<300).contains(http.statusCode), !data.isEmpty, data.count <= 12 * 1024 * 1024 else { return nil }
            let mime = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            guard mime.hasPrefix("image/") || Self.hasRecognizedImageSignature(data) else { return nil }
            imageDataCache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
            return data
        }
        return nil
    }


    private static func hasRecognizedImageSignature(_ data: Data) -> Bool {
        let bytes = [UInt8](data.prefix(16))
        if bytes.count >= 8, Array(bytes[0..<8]) == [137, 80, 78, 71, 13, 10, 26, 10] { return true }
        if bytes.count >= 3, bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF { return true }
        if bytes.count >= 6, String(bytes: bytes[0..<6], encoding: .ascii)?.hasPrefix("GIF8") == true { return true }
        if bytes.count >= 12, String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF",
           String(bytes: bytes[8..<12], encoding: .ascii) == "WEBP" { return true }
        if bytes.count >= 12, String(bytes: bytes[4..<8], encoding: .ascii) == "ftyp" {
            let brand = String(bytes: bytes[8..<12], encoding: .ascii) ?? ""
            if ["avif", "avis", "heic", "heix", "hevc", "hevx", "mif1", "msf1"].contains(brand) { return true }
        }
        return false
    }

    func attachmentData(_ url: URL, auth: SchoologyAuth, cookies: [SchoologyWebCookie], allowHTMLAttachment: Bool = false) async throws -> (Data, String) {
        guard url.scheme?.lowercased() == "https", url.host != nil else { throw SchoologyAPIError.invalidResponse }
        await syncServerTime()
        let session = URLSession(configuration: .ephemeral)
        let redirectDelegate = NoRedirectDelegate()
        defer { session.invalidateAndCancel() }
        var currentURL = url
        for redirectCount in 0...5 {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 45
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.setValue("https://\(webHost)/", forHTTPHeaderField: "Referer")
            // Only forward Schoology session cookies to Schoology-owned hosts.
            if let host = currentURL.host?.lowercased() {
                let suffix = useCanadianServer ? "schoologyca.com" : "schoology.com"
                let matchingCookies = cookies.filter { cookie in
                    let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    let pathMatches = currentURL.path.hasPrefix(cookie.path.isEmpty ? "/" : cookie.path)
                    return pathMatches && (host == domain || host.hasSuffix("." + domain)) &&
                        (domain == suffix || domain.hasSuffix("." + suffix))
                }
                if host == suffix || host.hasSuffix("." + suffix) {
                    let mobileValue = mobileCookie.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
                    let pairs = (["s_mobile=\(mobileValue)"] + matchingCookies.map { "\($0.name)=\($0.value)" })
                    request.setValue(pairs.joined(separator: "; "), forHTTPHeaderField: "Cookie")
                }
            }
            if currentURL.host?.caseInsensitiveCompare(apiHost) == .orderedSame {
                request.setValue("Android", forHTTPHeaderField: "X-Schoology-Client")
                request.setValue("2026.10.0", forHTTPHeaderField: "X-Schoology-App-Version")
                request.setValue(try authorization(method: "GET", url: currentURL, auth: auth, extra: []), forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await session.data(for: request, delegate: redirectDelegate)
            guard let http = response as? HTTPURLResponse else { throw SchoologyAPIError.invalidResponse }
            if (300...399).contains(http.statusCode), redirectCount < 5,
               let location = http.value(forHTTPHeaderField: "Location"),
               let nextURL = URL(string: location, relativeTo: currentURL)?.absoluteURL,
               nextURL.scheme?.lowercased() == "https" {
                currentURL = nextURL
                continue
            }
            guard (200..<300).contains(http.statusCode) else {
                let detail = String(decoding: data.prefix(600), as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw SchoologyAPIError.http(http.statusCode, detail)
            }
            guard !data.isEmpty, data.count <= 100 * 1024 * 1024 else {
                throw SchoologyAPIError.invalidResponse
            }
            let mimeType = http.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
            if Self.isHTMLResponse(data, mimeType: mimeType) {
                if Self.isExpiredSchoologySessionPage(data, finalURL: currentURL, requestedURL: url, wasRedirected: redirectCount > 0) {
                    throw SchoologyAPIError.attachment("The Schoology file session expired. Sign in again and retry the download.")
                }
                let disposition = http.value(forHTTPHeaderField: "Content-Disposition") ?? ""
                guard allowHTMLAttachment || Self.dispositionNamesHTMLFile(disposition) else {
                    throw SchoologyAPIError.attachment("ClassWire received an HTML page instead of the requested attachment. The file may be unavailable or your session may have expired.")
                }
            }
            return (data, mimeType)
        }
        throw SchoologyAPIError.invalidResponse
    }

    private static func isHTMLResponse(_ data: Data, mimeType: String) -> Bool {
        if mimeType.lowercased().contains("text/html") { return true }
        let prefix = String(decoding: data.prefix(1_024), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return prefix.hasPrefix("<!doctype html") || prefix.hasPrefix("<html") ||
            prefix.hasPrefix("<head") || prefix.hasPrefix("<form")
    }

    private static func dispositionNamesHTMLFile(_ value: String) -> Bool {
        for component in value.split(separator: ";").dropFirst() {
            let pair = component.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("filename") else { continue }
            let rawName = pair[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
            let filename = rawName.removingPercentEncoding ?? rawName
            if ["html", "htm"].contains(URL(fileURLWithPath: filename).pathExtension.lowercased()) {
                return true
            }
        }
        return false
    }

    private static func isExpiredSchoologySessionPage(
        _ data: Data,
        finalURL: URL,
        requestedURL: URL,
        wasRedirected: Bool
    ) -> Bool {
        let html = String(decoding: data.prefix(1_000_000), as: UTF8.self).lowercased()
        let pathParts = finalURL.path.lowercased().split(separator: "/").map(String.init)
        let isAuthenticationPath = pathParts.contains { ["login", "log-in", "signin", "sign-in", "authenticate"].contains($0) }
        let changedDestination = finalURL.host?.caseInsensitiveCompare(requestedURL.host ?? "") != .orderedSame ||
            finalURL.path != requestedURL.path
        let hasPasswordField = html.range(
            of: #"<input\b[^>]*type\s*=\s*["']?password"#,
            options: .regularExpression
        ) != nil
        let hasSchoologySignInCopy = html.contains("schoology") &&
            (html.contains("sign in") || html.contains("log in") || html.contains("log into"))
        let expiredCopy = html.contains("your session has expired") ||
            html.contains("this session has expired") ||
            html.contains("session expired")
        if wasRedirected && changedDestination && isAuthenticationPath { return true }
        if expiredCopy && (hasPasswordField || isAuthenticationPath || wasRedirected) { return true }
        return wasRedirected && hasPasswordField && hasSchoologySignInCopy
    }

    private func requestToken() async throws -> SchoologyAuth {
        let url = URL(string: "https://\(apiHost)/v1/oauth/request_token")!
        let emptyAuth = SchoologyAuth(token: "", secret: "", userID: "")
        let data = try await send(url: url, method: "GET", body: nil, auth: emptyAuth, signed: true, extra: [], clientIdentity: false)
        let values = parseForm(String(decoding: data, as: UTF8.self))
        guard let token = values["oauth_token"], let secret = values["oauth_token_secret"] else { throw SchoologyAPIError.invalidToken }
        return SchoologyAuth(token: token, secret: secret, userID: "")
    }

    private func exchangeToken(_ temporary: SchoologyAuth) async throws -> SchoologyAuth {
        let url = URL(string: "https://\(apiHost)/v1/oauth/access_token")!
        let data = try await send(url: url, method: "GET", body: nil, auth: temporary, signed: true, extra: [])
        let values = parseForm(String(decoding: data, as: UTF8.self))
        guard let token = values["oauth_token"], let secret = values["oauth_token_secret"] else { throw SchoologyAPIError.invalidToken }
        // The session layer performs one /users/me verification before it stores
        // credentials. Keeping verification there avoids duplicate signed requests.
        return SchoologyAuth(token: token, secret: secret, userID: "")
    }

    private func syncServerTime(force: Bool = false) async {
        if !force, let lastServerTimeSync,
           Date.now.timeIntervalSince(lastServerTimeSync) < 30 {
            return
        }
        guard let url = URL(string: "https://\(webHost)/oauth/timestamp") else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 15
        if let (data, response) = try? await URLSession.shared.data(for: request),
           (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) == true,
           let server = Int64(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) {
            timeOffset = server - Int64(Date.now.timeIntervalSince1970)
            lastServerTimeSync = .now
        }
    }

    private func nextOAuthNonce() -> String {
        // Match Tauri's 128-bit random value plus a monotonically increasing
        // sequence. Explicitly reject recent collisions before returning a nonce.
        var nonce = ""
        repeat {
            oauthNonceCounter &+= 1
            let randomHigh = UInt64.random(in: UInt64.min...UInt64.max)
            let randomLow = UInt64.random(in: UInt64.min...UInt64.max)
            nonce = String(format: "%016llx%016llx%016llx",
                           CUnsignedLongLong(randomHigh),
                           CUnsignedLongLong(randomLow),
                           CUnsignedLongLong(oauthNonceCounter))
        } while recentOAuthNonces.contains(nonce)

        recentOAuthNonces.insert(nonce)
        oauthNonceOrder.append(nonce)
        if oauthNonceOrder.count > 4096 {
            let expired = oauthNonceOrder.removeFirst()
            recentOAuthNonces.remove(expired)
        }
        return nonce
    }

    private func plaintextAuthorization(auth: SchoologyAuth) -> String {
        let nonce = nextOAuthNonce()
        let timestamp = Int64(Date.now.timeIntervalSince1970) + timeOffset
        let fields = [
            ("oauth_consumer_key", consumerKey),
            ("oauth_nonce", nonce),
            ("oauth_signature", "\(consumerSecret)%26\(auth.secret)"),
            ("oauth_signature_method", "PLAINTEXT"),
            ("oauth_timestamp", String(timestamp)),
            ("oauth_token", auth.token)
        ]
        return "OAuth " + fields.map { "\($0.0)=\"\($0.1)\"" }.joined(separator: ", ")
    }

    func uploadMessageFile(data: Data, filename: String, mime: String, auth: SchoologyAuth) async throws -> String {
        await syncServerTime()
        let boundary = UUID().uuidString
        let safeFilename = filename
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "\r", with: "%0D")
            .replacingOccurrences(of: "\n", with: "%0A")
        var multipart = Data()
        multipart.append(Data("--\(boundary)\r\n".utf8))
        multipart.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFilename)\"\r\n".utf8))
        multipart.append(Data("Content-Type: \(mime)\r\n".utf8))
        multipart.append(Data("Content-Length: \(data.count)\r\n\r\n".utf8))
        multipart.append(data)
        multipart.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var components = URLComponents()
        components.scheme = "https"
        components.host = apiHost
        components.path = "/v1/file"
        components.queryItems = [URLQueryItem(name: "name", value: filename)]
        guard let uploadURL = components.url else { throw SchoologyAPIError.invalidResponse }
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.httpBody = multipart
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Android", forHTTPHeaderField: "X-Schoology-Client")
        request.setValue("2026.10.0", forHTTPHeaderField: "X-Schoology-App-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(String(multipart.count), forHTTPHeaderField: "Content-Length")
        request.setValue(mobileCookie, forHTTPHeaderField: "Cookie")
        request.setValue(plaintextAuthorization(auth: auth), forHTTPHeaderField: "Authorization")
        let (uploadedData, uploadedResponse) = try await URLSession.shared.data(for: request)
        try validate(uploadedResponse, data: uploadedData)
        let uploaded = try JSONSerialization.jsonObject(with: uploadedData) as? [String: Any] ?? [:]
        guard let rawID = uploaded["fileMetadataId"] else { throw SchoologyAPIError.invalidResponse }
        let fileID = String(describing: rawID)
        guard !fileID.isEmpty else { throw SchoologyAPIError.invalidResponse }
        return fileID
    }

    func uploadAssignmentFile(data: Data, filename: String, mime: String, auth: SchoologyAuth) async throws -> String {
        await syncServerTime()
        let boundary = UUID().uuidString
        let safeFilename = filename
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "\r", with: "%0D")
            .replacingOccurrences(of: "\n", with: "%0A")
        var multipart = Data()
        multipart.append(Data("--\(boundary)\r\n".utf8))
        multipart.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFilename)\"\r\n".utf8))
        multipart.append(Data("Content-Type: \(mime)\r\n".utf8))
        multipart.append(Data("Content-Length: \(data.count)\r\n\r\n".utf8))
        multipart.append(data)
        multipart.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var components = URLComponents()
        components.scheme = "https"
        components.host = apiHost
        components.path = "/v1/file"
        components.queryItems = [URLQueryItem(name: "name", value: filename)]
        guard let uploadURL = components.url else { throw SchoologyAPIError.invalidResponse }
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.httpBody = multipart
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Android", forHTTPHeaderField: "X-Schoology-Client")
        request.setValue("2026.10.0", forHTTPHeaderField: "X-Schoology-App-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(String(multipart.count), forHTTPHeaderField: "Content-Length")
        request.setValue(mobileCookie, forHTTPHeaderField: "Cookie")
        request.setValue(plaintextAuthorization(auth: auth), forHTTPHeaderField: "Authorization")
        let (uploadedData, uploadedResponse) = try await URLSession.shared.data(for: request)
        try validate(uploadedResponse, data: uploadedData)
        let uploaded = try JSONSerialization.jsonObject(with: uploadedData) as? [String: Any] ?? [:]
        guard let fileID = uploaded["fileMetadataId"].map({ String(describing: $0) }), !fileID.isEmpty else {
            throw SchoologyAPIError.invalidResponse
        }
        return fileID
    }

    private func send(
        url: URL,
        method: String,
        body: String?,
        auth: SchoologyAuth?,
        signed: Bool,
        extra: [(String, String)],
        clientIdentity: Bool = true,
        contentType: String = "application/x-www-form-urlencoded",
        cookieHeader: String? = nil
    ) async throws -> Data {
        if signed {
            // Keep OAuth timestamps aligned for all signed requests, including GETs.
            // Cache successful server-time syncs briefly to avoid extra round trips.
            await syncServerTime()
        }

        // Schoology can redirect API requests. Match the Tauri host's behavior:
        // disable automatic redirect replay and create a fresh OAuth signature for
        // every same-host HTTPS redirect.
        let session = URLSession(configuration: .ephemeral)
        let redirectDelegate = NoRedirectDelegate()
        defer { session.invalidateAndCancel() }

        var currentURL = url
        var currentMethod = method.uppercased()
        var currentBody = body
        var redirectCount = 0
        var replayRetryCount = 0

        // Allow up to five same-host redirects plus three fresh-signature retries
        // when Schoology explicitly rejects a timestamp/nonce pair as a replay.
        for _ in 0...8 {
            var request = URLRequest(url: currentURL)
            request.httpMethod = currentMethod
            request.timeoutInterval = 45
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let isAPIHost = currentURL.host?.caseInsensitiveCompare(apiHost) == .orderedSame
            if clientIdentity && isAPIHost {
                request.setValue("Android", forHTTPHeaderField: "X-Schoology-Client")
                request.setValue("2026.10.0", forHTTPHeaderField: "X-Schoology-App-Version")
            }
            if auth != nil && isAPIHost {
                var cookieParts = [mobileCookie]
                if let cookieHeader, !cookieHeader.isEmpty {
                    cookieParts.append(cookieHeader)
                }
                request.setValue(cookieParts.joined(separator: "; "), forHTTPHeaderField: "Cookie")
            } else if let cookieHeader, !cookieHeader.isEmpty {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            if let currentBody {
                request.httpBody = currentBody.data(using: .utf8)
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
            if signed {
                request.setValue(
                    try authorization(method: currentMethod, url: currentURL, auth: auth, extra: extra),
                    forHTTPHeaderField: "Authorization"
                )
            }

            let (data, response) = try await session.data(for: request, delegate: redirectDelegate)
            guard let http = response as? HTTPURLResponse else {
                throw SchoologyAPIError.invalidResponse
            }

            if (300...399).contains(http.statusCode),
               let location = http.value(forHTTPHeaderField: "Location"),
               let nextURL = URL(string: location, relativeTo: currentURL)?.absoluteURL,
               nextURL.scheme?.lowercased() == "https",
               nextURL.host?.caseInsensitiveCompare(apiHost) == .orderedSame,
               redirectCount < 5 {
                redirectCount += 1
                if http.statusCode == 303 ||
                    ([301, 302, 307].contains(http.statusCode) && currentMethod != "GET" && currentMethod != "HEAD") {
                    if http.statusCode != 307 {
                        currentMethod = "GET"
                        currentBody = nil
                    }
                }
                currentURL = nextURL
                continue
            }

            if signed, replayRetryCount < 3, http.statusCode == 401 {
                let responseText = String(decoding: data.prefix(1_200), as: UTF8.self)
                    .lowercased()
                let isReplayRejection =
                    responseText.contains("duplicate timestamp/nonce combination") ||
                    responseText.contains("possible replay attack")
                if isReplayRejection {
                    // The server rejected this request before processing it.
                    // Rebuild the Authorization header on the next pass so both
                    // oauth_nonce and oauth_signature are fresh.
                    replayRetryCount += 1
                    await syncServerTime(force: true)
                    continue
                }
            }

            try validate(response, data: data)
            return data
        }

        throw SchoologyAPIError.invalidResponse
    }

    private func authorization(method: String, url: URL, auth: SchoologyAuth?, extra: [(String, String)]) throws -> String {
        let nonce = nextOAuthNonce()
        let timestamp = Int64(Date.now.timeIntervalSince1970) + timeOffset
        var pairs = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.map { ($0.name, $0.value ?? "") } ?? []
        pairs += [
            ("oauth_consumer_key", consumerKey),
            ("oauth_nonce", nonce),
            ("oauth_signature_method", "HMAC-SHA1"),
            ("oauth_timestamp", String(timestamp)),
            ("oauth_version", "1.0"),
            ("oauth_token", auth?.token ?? "")
        ]
        pairs += extra
        pairs.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        let normalized = pairs.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        let baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")\(url.path)"
        let base = "\(method.uppercased())&\(oauthEncode(baseURL))&\(oauthEncode(normalized))"
        let signingKey = "\(consumerSecret)&\(auth?.secret ?? "")"
        let key = SymmetricKey(data: Data(signingKey.utf8))
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: Data(base.utf8), using: key)
        let encodedSignature = Data(signature).base64EncodedString()
        let fields = [
            "oauth_consumer_key": consumerKey,
            "oauth_token": auth?.token ?? "",
            "oauth_nonce": nonce,
            "oauth_timestamp": String(timestamp),
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_version": "1.0",
            "oauth_signature": encodedSignature
        ]
        return "OAuth " + fields.keys.sorted().map { "\($0)=\"\(oauthEncode(fields[$0] ?? ""))\"" }.joined(separator: ", ")
    }

    private func validate(_ response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { throw SchoologyAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = data.map { String(decoding: $0.prefix(600), as: UTF8.self) } ?? ""
            throw SchoologyAPIError.http(http.statusCode, detail)
        }
    }

    private func parseForm(_ value: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: URLComponents(string: "?" + value)?.queryItems?.map { ($0.name, $0.value ?? "") } ?? [])
    }

    private func formEncode(_ values: [String: String]) -> String {
        values.keys.sorted().map { "\(oauthEncode($0))=\(oauthEncode(values[$0] ?? ""))" }.joined(separator: "&")
    }

    private func oauthEncode(_ value: String) -> String { encodeOAuthBytes(value) }

    private func encodeOAuthBytes(_ value: String) -> String {
        var output = ""
        for byte in value.utf8 {
            switch byte {
            case 65...90, 97...122, 48...57, 45, 95, 46: output += String(decoding: [byte], as: UTF8.self)
            case 42: output.append("*")
            case 32: output.append("+")
            default: output += String(format: "%%%02X", byte)
            }
        }
        return output
    }
}
