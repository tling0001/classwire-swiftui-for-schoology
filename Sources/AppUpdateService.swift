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
            request.setValue("ClassWire-SwiftUI-Classic-Switcher", forHTTPHeaderField: "User-Agent")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard release.draft != true, release.prerelease != true else {
                throw NSError(domain: "ClassWireClassicSwitcher", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No stable ClassWire Classic release is currently available."])
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
                throw NSError(domain: "ClassWireClassicSwitcher", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "The latest Classic release does not include a macOS installer for this Mac's architecture."])
            }
            classicMacOSDownloadURL = asset.browserDownloadURL
            classicAssetSize = asset.size
            classicAssetDigest = asset.digest
            #else
            guard let asset = release.assets.first(where: { $0.name.hasSuffix("-iOS-AdHoc.plist") }) else {
                throw NSError(domain: "ClassWireClassicSwitcher", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "The latest Classic release does not include an iOS Ad Hoc installation manifest."])
            }
            classicIOSManifestURL = asset.browserDownloadURL
            classicAssetSize = asset.size
            classicAssetDigest = asset.digest
            #endif
        } catch {
            classicErrorMessage = "Could not find ClassWire Classic: \(error.localizedDescription)"
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
            let endpoint = URL(string: "https://api.github.com/repos/tling0001/classwire-swiftui-for-schoology/releases/latest")!
            var request = URLRequest(url: endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("ClassWire-SwiftUI", forHTTPHeaderField: "User-Agent")
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
                $0.name == "ClassWire-\(release.tagName)-macOS.dmg"
            }?.browserDownloadURL
            iOSManifestURL = release.assets.first {
                $0.name == "ClassWire-\(release.tagName)-iOS-AdHoc.plist"
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
                throw NSError(domain: "ClassWireUpdater", code: 10, userInfo: [NSLocalizedDescriptionKey: "The macOS update installer is not available yet."])
            }
            try await installMacOSApp(downloadURL: downloadURL, expectedSize: nil, expectedDigest: nil, isClassic: false)
            #elseif os(iOS)
            guard let url = installURL else {
                throw NSError(domain: "ClassWireUpdater", code: 11, userInfo: [NSLocalizedDescriptionKey: "The iOS installation manifest is not available yet."])
            }
            guard await UIApplication.shared.open(url) else {
                throw NSError(domain: "ClassWireUpdater", code: 12, userInfo: [NSLocalizedDescriptionKey: "ClassWire could not open the iOS installation link."])
            }
            installationNotice = "Installation will start after closing ClassWire or returning to your Home Screen."
            #endif
        } catch {
            installErrorMessage = error.localizedDescription
            throw error
        }
    }

    func installClassic() async throws {
        #if os(macOS)
        guard let downloadURL = classicMacOSDownloadURL else {
            throw NSError(domain: "ClassWireUpdater", code: 13, userInfo: [NSLocalizedDescriptionKey: "The ClassWire Classic installer is not available."])
        }
        try await installMacOSApp(downloadURL: downloadURL, expectedSize: classicAssetSize, expectedDigest: classicAssetDigest, isClassic: true)
        #elseif os(iOS)
        guard let url = classicInstallURL else {
            throw NSError(domain: "ClassWireUpdater", code: 14, userInfo: [NSLocalizedDescriptionKey: "The ClassWire Classic installation manifest is not available."])
        }
        guard await UIApplication.shared.open(url) else {
            throw NSError(domain: "ClassWireUpdater", code: 15, userInfo: [NSLocalizedDescriptionKey: "ClassWire could not open the Classic installation link."])
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
        let runningBundleURL = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
        let isTranslocated = runningBundleURL.path.contains("/AppTranslocation/") ||
            runningBundleURL.path.hasPrefix("/Volumes/")
        let installedCandidates = [
            URL(fileURLWithPath: "/Applications/ClassWire.app", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/ClassWire.app", isDirectory: true)
        ]
        let targetApp: URL
        if isTranslocated {
            guard let installed = installedCandidates.first(where: {
                Bundle(url: $0)?.bundleIdentifier == "com.schoologytauri.app"
            }) else {
                throw NSError(domain: "ClassWireUpdater", code: 16, userInfo: [
                    NSLocalizedDescriptionKey: "ClassWire is running from a disk image or a quarantined temporary location. Move ClassWire into Applications, open it there, and try the update again."
                ])
            }
            targetApp = installed
        } else {
            targetApp = runningBundleURL
        }
        guard Bundle(url: targetApp)?.bundleIdentifier == "com.schoologytauri.app" else {
            throw NSError(domain: "ClassWireUpdater", code: 17, userInfo: [
                NSLocalizedDescriptionKey: "The running app bundle could not be identified as ClassWire."
            ])
        }

        let workDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("ClassWireUpdate-\(UUID().uuidString)", isDirectory: true)
        let logDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/ClassWire", isDirectory: true)
        let logURL = logDirectory.appendingPathComponent("update-\(Int(Date().timeIntervalSince1970)).log")
        try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
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
                    throw NSError(domain: "ClassWireUpdater", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "The downloaded installer size does not match the GitHub release metadata."])
                }
            }
            if let expectedDigest, expectedDigest.lowercased().hasPrefix("sha256:") {
                let fileData = try Data(contentsOf: downloadedFile)
                let actualDigest = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
                let expected = String(expectedDigest.dropFirst("sha256:".count)).lowercased()
                guard actualDigest == expected else {
                    throw NSError(domain: "ClassWireUpdater", code: 3,
                                  userInfo: [NSLocalizedDescriptionKey: "The downloaded installer failed its SHA-256 integrity check."])
                }
            }

            let dmgURL = workDirectory.appendingPathComponent("ClassWire-update.dmg")
            try fileManager.moveItem(at: downloadedFile, to: dmgURL)
            let scriptURL = workDirectory.appendingPathComponent("install-update.zsh")
            let appPID = ProcessInfo.processInfo.processIdentifier
            func quote(_ value: String) -> String {
                "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
            }
            let classicFlag = isClassic ? "1" : "0"
            let scriptTemplate = """
            #!/bin/zsh
            set -euo pipefail

            log() {
              print -r -- "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] $*"
            }

            perform_swap() {
              local TARGET_PARENT
              local STAGED_APP
              local BACKUP_APP
              TARGET_PARENT="$(/usr/bin/dirname "$TARGET_APP")"
              STAGED_APP="$TARGET_PARENT/.ClassWire-update-new.app"
              BACKUP_APP="$TARGET_PARENT/.ClassWire-update-backup.app"

              /bin/mkdir -p "$TARGET_PARENT"
              if [[ -d "$BACKUP_APP" && ! -d "$TARGET_APP" ]]; then
                /bin/mv "$BACKUP_APP" "$TARGET_APP"
              fi
              /bin/rm -rf "$STAGED_APP" "$BACKUP_APP"
              log "Copying the downloaded app to a staging bundle beside the installed app."
              if ! /usr/bin/ditto --rsrc --extattr --qtn "$SOURCE_APP" "$STAGED_APP"; then
                log "ERROR: Could not copy the downloaded app into the staging location."
                return 1
              fi

              if [[ "$INSTALL_CLASSIC" == "1" ]]; then
                /usr/bin/xattr -dr com.apple.quarantine "$STAGED_APP" 2>/dev/null || true
                if ! /usr/bin/codesign --force --deep --sign - "$STAGED_APP"; then
                  log "ERROR: Could not prepare the Classic app signature."
                  return 1
                fi
              elif ! /usr/bin/codesign --verify --deep --strict "$STAGED_APP"; then
                log "ERROR: The staged ClassWire app failed signature verification."
                return 1
              fi

              if [[ -d "$TARGET_APP" ]] && ! /bin/mv "$TARGET_APP" "$BACKUP_APP"; then
                log "ERROR: Could not move the existing app to its rollback location."
                return 1
              fi
              if ! /bin/mv "$STAGED_APP" "$TARGET_APP"; then
                [[ ! -d "$BACKUP_APP" ]] || /bin/mv "$BACKUP_APP" "$TARGET_APP"
                return 1
              fi
              if [[ "$INSTALL_CLASSIC" != "1" ]] &&
                 ! /usr/bin/codesign --verify --deep --strict "$TARGET_APP"; then
                log "The installed bundle failed signature verification; restoring the previous app."
                /bin/rm -rf "$TARGET_APP"
                [[ ! -d "$BACKUP_APP" ]] || /bin/mv "$BACKUP_APP" "$TARGET_APP"
                return 1
              fi
              /bin/rm -rf "$BACKUP_APP"
              log "The new app bundle was installed and verified."
            }

            if [[ "${1:-}" == "--elevated-swap" ]]; then
              TARGET_APP="$2"
              SOURCE_APP="$3"
              LOG_FILE="$4"
              INSTALL_CLASSIC="$5"
              exec >> "$LOG_FILE" 2>&1
              log "Administrator authorization granted for the app replacement."
              if ! perform_swap; then
                log "ERROR: The administrator-authorized app replacement failed."
                exit 1
              fi
              exit 0
            fi

            APP_PID=__APP_PID__
            DMG_PATH=__DMG_PATH__
            TARGET_APP=__TARGET_APP__
            WORK_DIR=__WORK_DIR__
            LOG_FILE=__LOG_FILE__
            INSTALL_CLASSIC=__INSTALL_CLASSIC__
            MOUNT_POINT="$WORK_DIR/mount"

            /bin/mkdir -p "$(/usr/bin/dirname "$LOG_FILE")"
            exec >> "$LOG_FILE" 2>&1

            cleanup() {
              /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
              /bin/rm -rf "$WORK_DIR"
            }
            trap cleanup EXIT

            log "Starting ClassWire macOS update."
            log "Target app: $TARGET_APP"
            log "Installer image: $DMG_PATH"

            for ((attempt = 0; attempt < 120; attempt++)); do
              if ! /bin/kill -0 "$APP_PID" 2>/dev/null; then break; fi
              /bin/sleep 1
            done
            if /bin/kill -0 "$APP_PID" 2>/dev/null; then
              log "ERROR: ClassWire did not finish quitting within 120 seconds."
              exit 1
            fi

            /bin/mkdir -p "$MOUNT_POINT"
            if ! /usr/bin/hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_POINT"; then
              log "ERROR: Could not mount the downloaded disk image."
              /usr/bin/open -n "$TARGET_APP" || true
              exit 1
            fi
            SOURCE_APP="$(/usr/bin/find "$MOUNT_POINT" -maxdepth 4 -name '*.app' -type d -print -quit)"
            if [[ -z "$SOURCE_APP" || ! -d "$SOURCE_APP" ]]; then
              log "ERROR: The downloaded disk image does not contain an application bundle."
              /usr/bin/open -n "$TARGET_APP" || true
              exit 1
            fi

            if [[ "$INSTALL_CLASSIC" == "1" ]]; then
              BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_APP/Contents/Info.plist")
              if [[ "$BUNDLE_ID" != "com.schoologytauri.app" ]]; then
                log "ERROR: The downloaded app does not have the expected ClassWire bundle identifier."
                /usr/bin/open -n "$TARGET_APP" || true
                exit 1
              fi
            elif ! /usr/bin/codesign --verify --deep --strict "$SOURCE_APP"; then
              log "ERROR: The downloaded ClassWire app failed signature verification."
              /usr/bin/open -n "$TARGET_APP" || true
              exit 1
            fi

            TARGET_PARENT="$(/usr/bin/dirname "$TARGET_APP")"
            if [[ -w "$TARGET_PARENT" ]]; then
              if ! perform_swap; then
                log "ERROR: App replacement failed; attempting to reopen the previous app."
                /usr/bin/open -n "$TARGET_APP" || true
                exit 1
              fi
            else
              log "The Applications folder requires administrator authorization. Requesting it before replacing ClassWire."
              ELEVATED_COMMAND="/bin/zsh $(printf '%q' "$0") --elevated-swap $(printf '%q' "$TARGET_APP") $(printf '%q' "$SOURCE_APP") $(printf '%q' "$LOG_FILE") $(printf '%q' "$INSTALL_CLASSIC")"
              if ! /usr/bin/osascript -e 'on run argv' -e 'do shell script (item 1 of argv) with administrator privileges' -e 'end run' "$ELEVATED_COMMAND"; then
                log "ERROR: Administrator authorization was cancelled or app replacement failed."
                /usr/bin/open -n "$TARGET_APP" || true
                exit 1
              fi
            fi

            /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet
            log "Launching the updated ClassWire app."
            if ! /usr/bin/open -n "$TARGET_APP"; then
              log "ERROR: The updated app was installed but Launch Services could not open it."
              exit 1
            fi
            log "Update completed successfully."
            """
            let script = scriptTemplate
                .replacingOccurrences(of: "__APP_PID__", with: String(appPID))
                .replacingOccurrences(of: "__DMG_PATH__", with: quote(dmgURL.path))
                .replacingOccurrences(of: "__TARGET_APP__", with: quote(targetApp.path))
                .replacingOccurrences(of: "__WORK_DIR__", with: quote(workDirectory.path))
                .replacingOccurrences(of: "__LOG_FILE__", with: quote(logURL.path))
                .replacingOccurrences(of: "__INSTALL_CLASSIC__", with: classicFlag)
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

            let helper = Process()
            helper.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
            helper.arguments = ["/bin/zsh", scriptURL.path]
            helper.standardInput = FileHandle.nullDevice
            helper.standardOutput = FileHandle.nullDevice
            helper.standardError = FileHandle.nullDevice
            try helper.run()
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
