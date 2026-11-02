import Foundation
import CryptoKit

enum SchoologyAPIError: LocalizedError {
    case invalidResponse
    case http(Int, String)
    case invalidToken
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Schoology returned an invalid response."
        case .http(let code, let detail): "Schoology request failed (HTTP \(code)): \(detail)"
        case .invalidToken: "Schoology did not return a valid access token."
        case .notSignedIn: "Please sign in to Schoology."
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
    private var useCanadianServer = false
    func setCanadianServer(_ enabled: Bool) { useCanadianServer = enabled }

    private var apiHost: String { useCanadianServer ? "api.schoologyca.com" : "api.schoology.com" }
    private var webHost: String { useCanadianServer ? "app.schoologyca.com" : "app.schoology.com" }

    func searchSchools(_ query: String) async throws -> [SchoologySchool] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let url = URL(string: "https://\(apiHost)/v1/login/school_search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
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
        let url = URL(string: "https://\(apiHost)/v1/oauth/qr_code_authorize_auto")!
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
              let host = parsed.host, !host.isEmpty else {
            throw SchoologyAPIError.invalidResponse
        }

        await syncServerTime()
        let temporary = try await requestToken()
        let callback = "https://\(host)/mobile_login_success?os=android&os_version=34&app_version=600000478"
        let encodedCallback = androidURIEncode(callback)
        let landingPath = "oauth/authorize?oauth_token=\(temporary.token)&oauth_callback=\(encodedCallback)"

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/oauth/authorize"
        components.queryItems = [
            URLQueryItem(name: "oauth_token", value: temporary.token),
            URLQueryItem(name: "oauth_callback", value: callback),
            URLQueryItem(name: "login_landing_dest", value: landingPath)
        ]
        guard let authorizationURL = components.url else { throw SchoologyAPIError.invalidResponse }
        return SchoologyPendingSchoolLogin(credential: temporary, authorizationURL: authorizationURL)
    }

    func completeSchoolBrowserLogin(
        _ pending: SchoologyPendingSchoolLogin,
        callbackURL: URL
    ) async throws -> SchoologyAuth {
        let callbackToken = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "request_token" })?.value
        guard callbackURL.scheme?.lowercased() == "schoology",
              callbackURL.host?.lowercased() == "external_login_callback",
              callbackToken == pending.credential.token else {
            throw SchoologyAPIError.invalidToken
        }
        return try await exchangeToken(pending.credential)
    }

    private func androidURIEncode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.!~*'()")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    func currentUser(auth: SchoologyAuth) async throws -> SchoologyUser {
        let data = try await get("users/me", auth: auth)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] else { throw SchoologyAPIError.invalidResponse }
        return SchoologyUser(
            id: String(describing: id),
            nameDisplay: json["name_display"] as? String ?? json["name"] as? String ?? "Schoology user",
            pictureURL: URL(string: json["picture_url"] as? String ?? "")
        )
    }

    func get(_ path: String, auth: SchoologyAuth, params: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(string: "https://\(apiHost)/v1/\(path)")!
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw SchoologyAPIError.invalidResponse }
        return try await send(url: url, method: "GET", body: nil, auth: auth, signed: true, extra: [])
    }

    private func requestToken() async throws -> SchoologyAuth {
        let url = URL(string: "https://\(apiHost)/v1/oauth/request_token")!
        let emptyAuth = SchoologyAuth(token: "", secret: "", userID: "")
        let data = try await send(url: url, method: "GET", body: nil, auth: emptyAuth, signed: true, extra: [])
        let values = parseForm(String(decoding: data, as: UTF8.self))
        guard let token = values["oauth_token"], let secret = values["oauth_token_secret"] else { throw SchoologyAPIError.invalidToken }
        return SchoologyAuth(token: token, secret: secret, userID: "")
    }

    private func exchangeToken(_ temporary: SchoologyAuth) async throws -> SchoologyAuth {
        let url = URL(string: "https://\(apiHost)/v1/oauth/access_token")!
        let data = try await send(url: url, method: "GET", body: nil, auth: temporary, signed: true, extra: [])
        let values = parseForm(String(decoding: data, as: UTF8.self))
        guard let token = values["oauth_token"], let secret = values["oauth_token_secret"] else { throw SchoologyAPIError.invalidToken }
        let provisional = SchoologyAuth(token: token, secret: secret, userID: "")
        let profile = try await currentUser(auth: provisional)
        return SchoologyAuth(token: token, secret: secret, userID: profile.id)
    }

    private func syncServerTime() async {
        guard let url = URL(string: "https://\(webHost)/oauth/timestamp") else { return }
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let server = Int64(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) {
            timeOffset = server - Int64(Date.now.timeIntervalSince1970)
        }
    }

    private func send(url: URL, method: String, body: String?, auth: SchoologyAuth?, signed: Bool, extra: [(String, String)]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 45
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Android", forHTTPHeaderField: "X-Schoology-Client")
        request.setValue("2026.10.0", forHTTPHeaderField: "X-Schoology-App-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if auth != nil {
            request.setValue(mobileCookie, forHTTPHeaderField: "Cookie")
        }
        if let body {
            request.httpBody = body.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        if signed {
            request.setValue(try authorization(method: method, url: url, auth: auth, extra: extra), forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return data
    }

    private func authorization(method: String, url: URL, auth: SchoologyAuth?, extra: [(String, String)]) throws -> String {
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
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
