import SwiftUI
import UserNotifications
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppUpdateService.self) private var updates
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
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
                            installAvailableUpdate()
                        }
                        .disabled(isUpdateInstallDisabled)
                        if updates.isInstallingUpdate {
                            ProgressView("Downloading and preparing update…")
                        }
                        if let installError {
                            Text(installError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                        }
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
        updates.macOSDownloadURL == nil || updates.isInstallingUpdate
        #else
        updates.installURL == nil || updates.isInstallingUpdate
        #endif
    }

    @MainActor
    private func installAvailableUpdate() {
        Task {
            do {
                installError = nil
                try await updates.installUpdate()
                #if os(iOS)
                showingIOSInstallNotice = true
                #endif
            } catch {
                installError = "Could not install the update: \(error.localizedDescription)"
            }
        }
    }

    #if os(macOS)
    @MainActor
    private func installClassicMacOS() async {
        guard updates.classicMacOSDownloadURL != nil, !isInstallingClassic else { return }
        isInstallingClassic = true
        classicInstallError = nil
        do {
            try await updates.installClassic()
        } catch {
            classicInstallError = "Could not switch to Schoology Classic: \(error.localizedDescription)"
            isInstallingClassic = false
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
