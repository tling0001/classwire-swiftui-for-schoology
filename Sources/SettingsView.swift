import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppUpdateService.self) private var updates
    @Environment(\.openURL) private var openURL

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
                            if let url = updates.installURL { openURL(url) }
                        }
                        .disabled(updates.installURL == nil)
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
}
