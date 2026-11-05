import SwiftUI
import UserNotifications
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
import CryptoKit
#endif

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppUpdateService.self) private var updates
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var isInstallingUpdate = false
    @State private var isInstallingClassic = false
    @State private var showingClassicConfirmation = false
    @State private var showingIOSInstallNotice = false
    @State private var installError: String?
    @State private var classicInstallError: String?

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { session.appearance },
                    set: { session.appearance = $0 }
                )) {
                    Text("System").tag(AppAppearance.system)
                    Text("Light").tag(AppAppearance.light)
                    Text("Dark").tag(AppAppearance.dark)
                }
                .schoologyNavigationTabPickerStyle()
                .tint(settingsAccent)
            }

            SchoologyNotificationSettingsSection()

            Section("Software Update") {
                LabeledContent("Current version", value: AppVersion.current)
                Button("Check for Updates", systemImage: "arrow.clockwise") {
                    Task { await updates.checkForUpdates(force: true) }
                }
                .buttonStyle(.borderedProminent)
                .tint(settingsAccent)
                .disabled(updates.isChecking)

                Divider()

                Button("Switch to Schoology Classic", systemImage: "arrow.uturn.backward") {
                    Task { await updates.checkForClassicRelease() }
                }
                .disabled(updates.isCheckingClassic || isInstallingClassic)

                if updates.isCheckingClassic {
                    ProgressView("Finding the latest Schoology Classic release…")
                } else if let classicVersion = updates.classicLatestVersion {
                    Label("Schoology Classic \(classicVersion)", systemImage: "desktopcomputer")
                        .foregroundStyle(.secondary)
                    Button("Install Schoology Classic", systemImage: "arrow.down.to.line") {
                        showingClassicConfirmation = true
                    }
                    .disabled(!updates.canInstallClassic || isInstallingClassic)
                    if let releaseURL = updates.classicReleaseURL {
                        Link("View Schoology Classic release", destination: releaseURL)
                    }
                }

                #if os(macOS)
                if isInstallingClassic {
                    ProgressView("Downloading and preparing Schoology Classic…")
                }
                #endif
                if let classicError = updates.classicErrorMessage {
                    Text(classicError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let classicInstallError {
                    Text(classicInstallError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                if updates.isChecking {
                    ProgressView("Checking for updates…")
                } else if let latestVersion = updates.latestVersion {
                    if updates.hasUpdate {
                        Label("Version \(latestVersion) is available", systemImage: "arrow.down.circle")
                        #if os(macOS)
                        let actionTitle = "Download Update"
                        #else
                        let actionTitle = "Install Update"
                        #endif
                        Button(actionTitle, systemImage: "arrow.down.to.line") {
                            #if os(macOS)
                            Task { await installMacOSUpdate() }
                            #else
                            if let url = updates.installURL {
                                openURL(url)
                                showingIOSInstallNotice = true
                            }
                            #endif
                        }
                        .disabled(isUpdateInstallDisabled)
                        #if os(macOS)
                        if isInstallingUpdate {
                            ProgressView("Downloading and preparing update…")
                        }
                        if let installError {
                            Text(installError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                        }
                        #endif
                    } else {
                        Label("You're up to date", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }

                    if let notes = updates.releaseNotes, !notes.isEmpty {
                        DisclosureGroup("Latest release notes") {
                            Text(notes)
                                .font(.callout)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if let releaseURL = updates.releaseURL {
                        Link("View GitHub release", destination: releaseURL)
                    }
                }

                if let error = updates.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Account") {
                NavigationLink {
                    SchoologyAccountInfoView()
                } label: {
                    Label("Account Info", systemImage: "person.text.rectangle")
                }
                if let user = session.user {
                    LabeledContent("Signed in as", value: user.nameDisplay)
                }
            }

            Section("About") {
                LabeledContent("Version", value: AppVersion.current)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(maxWidth: 720)
        .confirmationDialog("Switch to Schoology Classic?", isPresented: $showingClassicConfirmation, titleVisibility: .visible) {
            Button("Replace with Schoology Classic", role: .destructive) {
                #if os(macOS)
                Task { await installClassicMacOS() }
                #else
                if let url = updates.classicInstallURL { openURL(url) }
                #endif
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This replaces the current Schoology SwiftUI app with Schoology Classic. Your app will be updated in place and may close during installation.")
        }
        .alert("Installing update", isPresented: $showingIOSInstallNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Schoology installation will start after closing Schoology or going to your Home Screen.")
        }
    }

    private var settingsAccent: Color {
        colorScheme == .dark
            ? Color(red: 0.28, green: 0.62, blue: 0.91)
            : SchoologyStyle.blue
    }

    private var isUpdateInstallDisabled: Bool {
        #if os(macOS)
        updates.macOSDownloadURL == nil || isInstallingUpdate
        #else
        updates.installURL == nil
        #endif
    }

    #if os(macOS)
    @MainActor
    private func installMacOSUpdate() async {
        guard let downloadURL = updates.macOSDownloadURL, !isInstallingUpdate else { return }
        isInstallingUpdate = true
        installError = nil
        do {
            try await installMacOSApp(downloadURL: downloadURL, expectedSize: nil, expectedDigest: nil, isClassic: false)
        } catch {
            installError = "Could not install the update: \(error.localizedDescription)"
            isInstallingUpdate = false
        }
    }

    @MainActor
    private func installClassicMacOS() async {
        guard let downloadURL = updates.classicMacOSDownloadURL, !isInstallingClassic else { return }
        isInstallingClassic = true
        classicInstallError = nil
        do {
            try await installMacOSApp(
                downloadURL: downloadURL,
                expectedSize: updates.classicAssetSize,
                expectedDigest: updates.classicAssetDigest,
                isClassic: true
            )
        } catch {
            classicInstallError = "Could not switch to Schoology Classic: \(error.localizedDescription)"
            isInstallingClassic = false
        }
    }

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
}


struct SchoologyNotificationSettingsSection: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("schoology.notifications.enabled") private var notificationsEnabled = false
    @AppStorage("schoology.notifications.sound") private var notificationSound = false
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var errorMessage: String?
    @State private var pushRegistrationError: String?

    var body: some View {
        #if os(macOS)
        Section("Notifications") {
            if isAuthorized {
                Toggle("Schoology notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        Task { await SchoologyPushNotifications.setEnabled(enabled) }
                    }
                Toggle("Notification sound", isOn: $notificationSound)
                    .disabled(!notificationsEnabled)
                Text("Alerts follow your macOS notification settings. Sound preference applies while Schoology is open.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button(authorizationStatus == .denied ? "Open Notification Settings" : "Enable Schoology Notifications",
                       systemImage: authorizationStatus == .denied ? "gear" : "bell.badge") {
                    if authorizationStatus == .denied { openSystemNotificationSettings() }
                    else { Task { await requestPermission() } }
                }
                Text(authorizationStatus == .denied
                     ? "Notifications are blocked for Schoology. Allow them in System Settings to receive alerts."
                     : "Allow Schoology to send alerts for new messages, comments, and other activity.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
            if let pushRegistrationError { Text("Push registration failed: \(pushRegistrationError)").font(.footnote).foregroundStyle(.red) }
        }
        .task {
            await refreshAuthorization()
            pushRegistrationError = SchoologyPushNotifications.registrationError
        }
        .onReceive(NotificationCenter.default.publisher(for: .schoologyPushRegistrationDidChange)) { _ in
            pushRegistrationError = SchoologyPushNotifications.registrationError
        }
        #else
        Section("Notifications") {
            if isAuthorized {
                Toggle("Schoology notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        Task { await SchoologyPushNotifications.setEnabled(enabled) }
                    }
                Toggle("Notification sound", isOn: $notificationSound)
                    .disabled(!notificationsEnabled)
                Text("Vibration and alert appearance follow your iPhone or iPad notification settings. Sound preference applies while Schoology is open.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button(authorizationStatus == .denied ? "Open Notification Settings" : "Enable Schoology Notifications",
                       systemImage: authorizationStatus == .denied ? "gear" : "bell.badge") {
                    if authorizationStatus == .denied { openSystemNotificationSettings() }
                    else { Task { await requestPermission() } }
                }
                Text(authorizationStatus == .denied
                     ? "Notifications are blocked for Schoology. Allow them in system settings to receive alerts."
                     : "Allow Schoology to send alerts for new messages, comments, and other activity.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
            if let pushRegistrationError { Text("Push registration failed: \(pushRegistrationError)").font(.footnote).foregroundStyle(.red) }
        }
        .task {
            await refreshAuthorization()
            pushRegistrationError = SchoologyPushNotifications.registrationError
        }
        .onReceive(NotificationCenter.default.publisher(for: .schoologyPushRegistrationDidChange)) { _ in
            pushRegistrationError = SchoologyPushNotifications.registrationError
        }
        #endif
    }

    private var isAuthorized: Bool {
        #if os(iOS)
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
        #else
        authorizationStatus == .authorized || authorizationStatus == .provisional
        #endif
    }

    @MainActor private func refreshAuthorization() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @MainActor private func requestPermission() async {
        do {
            let granted = try await SchoologyPushNotifications.requestAuthorization()
            await refreshAuthorization()
            if granted { notificationsEnabled = true }
            else { errorMessage = "Notification permission wasn't granted." }
        } catch { errorMessage = error.localizedDescription }
    }

    private func openSystemNotificationSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { openURL(url) }
        #endif
    }
}
