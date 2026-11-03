import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppUpdateService.self) private var updates
    @Environment(\.openURL) private var openURL
    @State private var isInstallingUpdate = false
    @State private var installError: String?

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
            }

            Section("Software Update") {
                LabeledContent("Current version", value: AppVersion.current)
                Button("Check for Updates", systemImage: "arrow.clockwise") {
                    Task { await updates.checkForUpdates(force: true) }
                }
                .disabled(updates.isChecking)

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
                            if let url = updates.installURL { openURL(url) }
                            #endif
                        }
                        .disabled(
                            #if os(macOS)
                            updates.macOSDownloadURL == nil || isInstallingUpdate
                            #else
                            updates.installURL == nil
                            #endif
                        )
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
                Button("Sign out", role: .destructive) {
                    session.signOut()
                }
            }

            Section("About") {
                LabeledContent("Version", value: AppVersion.current)
                LabeledContent("Bundle identifier", value: "com.schoologytauri.app")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(maxWidth: 720)
    }

    #if os(macOS)
    @MainActor
    private func installMacOSUpdate() async {
        guard let downloadURL = updates.macOSDownloadURL, !isInstallingUpdate else { return }
        isInstallingUpdate = true
        installError = nil

        let fileManager = FileManager.default
        let workDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("SchoologyUpdate-\\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
            let (downloadedFile, response) = try await URLSession.shared.download(from: downloadURL)
            if let response = response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                throw URLError(.badServerResponse)
            }

            let dmgURL = workDirectory.appendingPathComponent("Schoology-update.dmg")
            try fileManager.moveItem(at: downloadedFile, to: dmgURL)

            let targetApp = Bundle.main.bundleURL.standardizedFileURL
            let scriptURL = workDirectory.appendingPathComponent("install-update.zsh")
            let appPID = ProcessInfo.processInfo.processIdentifier
            func quote(_ value: String) -> String {
                "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
            }

            let script = """
            #!/bin/zsh
            set -euo pipefail
            APP_PID=\\(appPID)
            DMG_PATH=\\(quote(dmgURL.path))
            TARGET_APP=\\(quote(targetApp.path))
            WORK_DIR=\\(quote(workDirectory.path))
            MOUNT_POINT="$WORK_DIR/mount"
            STAGED_APP="$TARGET_APP.update-new"
            BACKUP_APP="$TARGET_APP.update-backup"

            cleanup() {
              /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
              /bin/rm -rf "$WORK_DIR"
            }
            trap cleanup EXIT

            # Never replace an application bundle while its executable is running.
            while /bin/kill -0 "$APP_PID" 2>/dev/null; do
              /bin/sleep 1
            done

            /bin/mkdir -p "$MOUNT_POINT"
            /usr/bin/hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_POINT" >/dev/null
            SOURCE_APP="$MOUNT_POINT/Schoology.app"
            if [[ ! -d "$SOURCE_APP" ]]; then
              echo "The downloaded disk image does not contain Schoology.app." >&2
              exit 1
            fi

            /usr/bin/codesign --verify --deep --strict "$SOURCE_APP"
            /bin/rm -rf "$STAGED_APP" "$BACKUP_APP"
            /usr/bin/ditto "$SOURCE_APP" "$STAGED_APP"

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
            helper.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
            helper.arguments = ["/bin/zsh", scriptURL.path]
            helper.standardOutput = FileHandle.nullDevice
            helper.standardError = FileHandle.nullDevice
            try helper.run()

            // The detached helper waits for this process to exit before mounting
            // the image and replacing the app bundle.
            NSApp.terminate(nil)
        } catch {
            try? fileManager.removeItem(at: workDirectory)
            installError = "Could not install the update: \\(error.localizedDescription)"
            isInstallingUpdate = false
        }
    }
    #endif
}
