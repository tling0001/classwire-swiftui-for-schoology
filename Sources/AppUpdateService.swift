import Foundation
import Observation
#if os(macOS)
import AppKit
import CryptoKit
#elseif os(iOS)
import UIKit
#endif

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
            let size: Int64?
            let digest: String?

            enum CodingKeys: String, CodingKey {
                case name, size, digest
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let body: String?
        let htmlURL: URL
        let assets: [Asset]
        let draft: Bool?
        let prerelease: Bool?

        enum CodingKeys: String, CodingKey {
            case body, assets, draft, prerelease
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private(set) var latestVersion: String?
    private(set) var releaseNotes: String?
    private(set) var releaseURL: URL?
    private(set) var macOSDownloadURL: URL?
    private(set) var iOSManifestURL: URL?
    private(set) var classicLatestVersion: String?
    private(set) var classicReleaseURL: URL?
    private(set) var classicMacOSDownloadURL: URL?
    private(set) var classicIOSManifestURL: URL?
    private(set) var classicAssetSize: Int64?
    private(set) var classicAssetDigest: String?
    private(set) var isCheckingClassic = false
    private(set) var classicErrorMessage: String?
    private(set) var isChecking = false
    private(set) var errorMessage: String?
    private(set) var isInstallingUpdate = false
    private(set) var installErrorMessage: String?
    private(set) var installationNotice: String?
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

    var classicInstallURL: URL? {
        #if os(macOS)
        return classicMacOSDownloadURL
        #else
        guard let classicIOSManifestURL else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encodedManifest = classicIOSManifestURL.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "itms-services://?action=download-manifest&url=\(encodedManifest)")
        #endif
    }

    var canInstallClassic: Bool {
        #if os(macOS)
        classicMacOSDownloadURL != nil
        #else
        classicInstallURL != nil
        #endif
    }

    func checkForClassicRelease() async {
        guard !isCheckingClassic else { return }
        isCheckingClassic = true
        classicErrorMessage = nil
        defer { isCheckingClassic = false }

        do {
            let endpoint = URL(string: "https://api.github.com/repos/tling0001/schoology-for-desktop-port/releases/latest")!
            var request = URLRequest(url: endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Schoology-SwiftUI-Classic-Switcher", forHTTPHeaderField: "User-Agent")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard release.draft != true, release.prerelease != true else {
                throw NSError(domain: "SchoologyClassicSwitcher", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No stable Schoology Classic release is currently available."])
            }
            classicLatestVersion = release.tagName
            classicReleaseURL = release.htmlURL
            classicMacOSDownloadURL = nil
            classicIOSManifestURL = nil
            classicAssetSize = nil
            classicAssetDigest = nil

            #if os(macOS)
            #if arch(arm64)
            let suffix = "_aarch64.dmg"
            #elseif arch(x86_64)
            let suffix = "_x86_64.dmg"
            #else
            let suffix = ".dmg"
            #endif
            guard let asset = release.assets.first(where: { $0.name.hasSuffix(suffix) }) else {
                throw NSError(domain: "SchoologyClassicSwitcher", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "The latest Classic release does not include a macOS installer for this Mac's architecture."])
            }
            classicMacOSDownloadURL = asset.browserDownloadURL
            classicAssetSize = asset.size
            classicAssetDigest = asset.digest
            #else
            guard let asset = release.assets.first(where: { $0.name.hasSuffix("-iOS-AdHoc.plist") }) else {
                throw NSError(domain: "SchoologyClassicSwitcher", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "The latest Classic release does not include an iOS Ad Hoc installation manifest."])
            }
            classicIOSManifestURL = asset.browserDownloadURL
            classicAssetSize = asset.size
            classicAssetDigest = asset.digest
            #endif
        } catch {
            classicErrorMessage = "Could not find Schoology Classic: \(error.localizedDescription)"
        }
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
            installErrorMessage = nil
            installationNotice = nil
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

    /// Shared by the launch update notice and the Settings software-update section.
    func installUpdate() async throws {
        guard !isInstallingUpdate else { return }
        isInstallingUpdate = true
        installErrorMessage = nil
        installationNotice = nil
        defer { isInstallingUpdate = false }
        do {
            #if os(macOS)
            guard let downloadURL = macOSDownloadURL else {
                throw NSError(domain: "SchoologyUpdater", code: 10, userInfo: [NSLocalizedDescriptionKey: "The macOS update installer is not available yet."])
            }
            try await installMacOSApp(downloadURL: downloadURL, expectedSize: nil, expectedDigest: nil, isClassic: false)
            #elseif os(iOS)
            guard let url = installURL else {
                throw NSError(domain: "SchoologyUpdater", code: 11, userInfo: [NSLocalizedDescriptionKey: "The iOS installation manifest is not available yet."])
            }
            guard await UIApplication.shared.open(url) else {
                throw NSError(domain: "SchoologyUpdater", code: 12, userInfo: [NSLocalizedDescriptionKey: "Schoology could not open the iOS installation link."])
            }
            installationNotice = "Installation will start after closing Schoology or returning to your Home Screen."
            #endif
        } catch {
            installErrorMessage = error.localizedDescription
            throw error
        }
    }

    func installClassic() async throws {
        #if os(macOS)
        guard let downloadURL = classicMacOSDownloadURL else {
            throw NSError(domain: "SchoologyUpdater", code: 13, userInfo: [NSLocalizedDescriptionKey: "The Schoology Classic installer is not available."])
        }
        try await installMacOSApp(downloadURL: downloadURL, expectedSize: classicAssetSize, expectedDigest: classicAssetDigest, isClassic: true)
        #elseif os(iOS)
        guard let url = classicInstallURL else {
            throw NSError(domain: "SchoologyUpdater", code: 14, userInfo: [NSLocalizedDescriptionKey: "The Schoology Classic installation manifest is not available."])
        }
        guard await UIApplication.shared.open(url) else {
            throw NSError(domain: "SchoologyUpdater", code: 15, userInfo: [NSLocalizedDescriptionKey: "Schoology could not open the Classic installation link."])
        }
        #endif
    }

    #if os(macOS)
    @MainActor
    private func installMacOSApp(
        downloadURL: URL,
        expectedSize: Int64?,
        expectedDigest: String?,
        isClassic: Bool
    ) async throws {
        guard downloadURL.scheme?.lowercased() == "https",
              downloadURL.host?.lowercased() == "github.com" else {
            throw URLError(.badURL)
        }

        let fileManager = FileManager.default
        let workDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("SchoologyUpdate-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        do {
            let (downloadedFile, response) = try await URLSession.shared.download(from: downloadURL)
            if let response = response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                throw URLError(.badServerResponse)
            }

            if let expectedSize, expectedSize > 0 {
                let attributes = try fileManager.attributesOfItem(atPath: downloadedFile.path)
                let actualSize = (attributes[.size] as? NSNumber)?.int64Value ?? -1
                guard actualSize == expectedSize else {
                    throw NSError(domain: "SchoologyUpdater", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "The downloaded installer size does not match the GitHub release metadata."])
                }
            }
            if let expectedDigest, expectedDigest.lowercased().hasPrefix("sha256:") {
                let fileData = try Data(contentsOf: downloadedFile)
                let actualDigest = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
                let expected = String(expectedDigest.dropFirst("sha256:".count)).lowercased()
                guard actualDigest == expected else {
                    throw NSError(domain: "SchoologyUpdater", code: 3,
                                  userInfo: [NSLocalizedDescriptionKey: "The downloaded installer failed its SHA-256 integrity check."])
                }
            }

            let dmgURL = workDirectory.appendingPathComponent("Schoology-update.dmg")
            try fileManager.moveItem(at: downloadedFile, to: dmgURL)
            let targetApp = Bundle.main.bundleURL.standardizedFileURL
            let scriptURL = workDirectory.appendingPathComponent("install-update.zsh")
            let appPID = ProcessInfo.processInfo.processIdentifier
            func quote(_ value: String) -> String {
                "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
            }
            let classicFlag = isClassic ? "1" : "0"
            let script = """
            #!/bin/zsh
            set -euo pipefail
            APP_PID=\(appPID)
            DMG_PATH=\(quote(dmgURL.path))
            TARGET_APP=\(quote(targetApp.path))
            WORK_DIR=\(quote(workDirectory.path))
            INSTALL_CLASSIC=\(classicFlag)
            MOUNT_POINT="$WORK_DIR/mount"
            STAGED_APP="$TARGET_APP.update-new"
            BACKUP_APP="$TARGET_APP.update-backup"

            cleanup() {
              /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
              /bin/rm -rf "$WORK_DIR"
            }
            trap cleanup EXIT

            while /bin/kill -0 "$APP_PID" 2>/dev/null; do
              /bin/sleep 1
            done

            /bin/mkdir -p "$MOUNT_POINT"
            /usr/bin/hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_POINT" >/dev/null
            SOURCE_APP="$(/usr/bin/find "$MOUNT_POINT" -maxdepth 4 -name '*.app' -type d -print -quit)"
            if [[ -z "$SOURCE_APP" || ! -d "$SOURCE_APP" ]]; then
              echo "The downloaded disk image does not contain an application bundle." >&2
              exit 1
            fi

            if [[ "$INSTALL_CLASSIC" == "1" ]]; then
              BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_APP/Contents/Info.plist")
              if [[ "$BUNDLE_ID" != "com.schoologytauri.app" ]]; then
                echo "The downloaded app is not the official Schoology Classic bundle." >&2
                exit 1
              fi
            else
              /usr/bin/codesign --verify --deep --strict "$SOURCE_APP"
            fi

            /bin/rm -rf "$STAGED_APP" "$BACKUP_APP"
            /usr/bin/ditto --rsrc --extattr --qtn "$SOURCE_APP" "$STAGED_APP"

            if [[ "$INSTALL_CLASSIC" == "1" ]]; then
              /usr/bin/xattr -dr com.apple.quarantine "$STAGED_APP" 2>/dev/null || true
              /usr/bin/codesign --force --deep --sign - "$STAGED_APP" >/dev/null 2>&1 || true
            fi

            if [[ -d "$TARGET_APP" ]]; then
              /bin/mv "$TARGET_APP" "$BACKUP_APP"
            fi
            if /bin/mv "$STAGED_APP" "$TARGET_APP"; then
              /bin/rm -rf "$BACKUP_APP"
            else
              [[ ! -d "$BACKUP_APP" ]] || /bin/mv "$BACKUP_APP" "$TARGET_APP"
              exit 1
            fi

            /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet
            /usr/bin/open "$TARGET_APP"
            """

            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            let helper = Process()
            helper.executableURL = URL(fileURLWithPath: "/bin/sh")
            helper.arguments = [
                "-c",
                "/usr/bin/nohup /bin/zsh '\(scriptURL.path.replacingOccurrences(of: "'", with: "'\\''"))' </dev/null >/dev/null 2>&1 &"
            ]
            try helper.run()
            helper.waitUntilExit()
            guard helper.terminationStatus == 0 else {
                throw NSError(domain: "SchoologyUpdater", code: Int(helper.terminationStatus),
                              userInfo: [NSLocalizedDescriptionKey: "Could not start the update installer."])
            }
            NSApp.terminate(nil)
        } catch {
            try? fileManager.removeItem(at: workDirectory)
            throw error
        }
    }
    #endif
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
