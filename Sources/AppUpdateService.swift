import Foundation
import Observation

enum AppVersion {
    static var current: String {
        let marketing = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2026.10.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(marketing)-port.\(build)"
    }
}

@Observable
@MainActor
final class AppUpdateService {
    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let body: String?
        let htmlURL: URL
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case body, assets
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private(set) var latestVersion: String?
    private(set) var releaseNotes: String?
    private(set) var releaseURL: URL?
    private(set) var macOSDownloadURL: URL?
    private(set) var iOSManifestURL: URL?
    private(set) var isChecking = false
    private(set) var errorMessage: String?
    private var lastChecked: Date?

    var hasUpdate: Bool {
        guard let latestVersion else { return false }
        return Self.versionParts(AppVersion.current).lexicographicallyPrecedes(Self.versionParts(latestVersion))
    }

    var installURL: URL? {
        #if os(macOS)
        return macOSDownloadURL
        #else
        guard let iOSManifestURL else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encodedManifest = iOSManifestURL.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "itms-services://?action=download-manifest&url=\(encodedManifest)")
        #endif
    }

    func checkForUpdates(force: Bool = false) async {
        guard !isChecking else { return }
        if !force, let lastChecked, Date().timeIntervalSince(lastChecked) < 6 * 60 * 60 {
            return
        }

        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        do {
            let endpoint = URL(string: "https://api.github.com/repos/tling0001/schoology-swiftui/releases/latest")!
            var request = URLRequest(url: endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Schoology-SwiftUI", forHTTPHeaderField: "User-Agent")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestVersion = release.tagName
            releaseNotes = release.body
            releaseURL = release.htmlURL
            macOSDownloadURL = release.assets.first {
                $0.name == "Schoology-\(release.tagName)-macOS.dmg"
            }?.browserDownloadURL
            iOSManifestURL = release.assets.first {
                $0.name == "Schoology-\(release.tagName)-iOS-AdHoc.plist"
            }?.browserDownloadURL
            lastChecked = Date()

            #if os(macOS)
            if hasUpdate && macOSDownloadURL == nil {
                errorMessage = "A newer release exists, but its macOS installer is not attached yet."
            }
            #else
            if hasUpdate && iOSManifestURL == nil {
                errorMessage = "A newer release exists, but its iOS Ad Hoc installation manifest is not attached yet."
            }
            #endif
        } catch {
            errorMessage = "Could not check for updates: \(error.localizedDescription)"
        }
    }

    private static func versionParts(_ version: String) -> [Int] {
        let sections = version.split(separator: "-", omittingEmptySubsequences: false)
        let marketing = sections.first.map { $0.split(separator: ".").compactMap { Int($0) } } ?? []
        let port = sections.dropFirst().first.flatMap { section -> Int? in
            guard section.hasPrefix("port.") else { return nil }
            return Int(section.dropFirst("port.".count))
        } ?? 0
        return marketing + [port]
    }
}
