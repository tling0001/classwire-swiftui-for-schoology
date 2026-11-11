import SwiftUI

struct ClassWireAISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: ClassWireAIAssistantStore
    @State private var keyInput = ""
    @State private var keyStatus = ""
    @State private var showingPuterConnect = false
    @State private var puterService = ClassWirePuterService.shared

    var body: some View {
        Form {
                providerSection
                if store.provider == .gemini {
                    googleCloudSection
                }
                privacySection
            }
            .navigationTitle("AI Settings")
            .sheet(isPresented: $showingPuterConnect) {
                NavigationStack {
                    ClassWirePuterConnectSheet(service: puterService)
                }
                .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.persistSettings()
                        dismiss()
                    }
                }
            }
            .onChange(of: store.provider) { _, provider in
                store.model = provider.defaultModel
                keyInput = ""
                keyStatus = ""
                store.persistSettings()
                Task { await store.refreshKeyStatus() }
            }
            .onChange(of: store.ollamaEndpoint) { _, _ in store.persistSettings() }
            .task {
                await puterService.refreshAuthStatus()
                await store.refreshKeyStatus()
            }
    }

    private var providerSection: some View {
        Section("AI provider") {
            providerPicker
            Text("Choose your model from the menu beside the message composer.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if store.provider == .puter {
                puterControls
                if let error = puterService.signInError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            } else if store.provider.requiresAPIKey {
                apiKeyControls
            } else {
                ollamaControls
            }
            keyStatusMessage
        }
    }

    private var providerPicker: some View {
        Picker("Provider", selection: $store.provider) {
            ForEach(ClassWireAIProvider.allCases) { provider in
                Text(provider.title).tag(provider)
            }
        }
    }

    private var puterControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if puterService.isSignedIn {
                Label("Connected to Puter", systemImage: "checkmark.circle.fill").foregroundStyle(.secondary)
                if !puterService.accountLabel.isEmpty {
                    Text(puterService.accountLabel).font(.footnote).foregroundStyle(.secondary)
                }
                Button("Disconnect Puter", role: .destructive) {
                    Task { await puterService.signOut(); await store.refreshKeyStatus() }
                }
            } else {
                Text("Connect your Puter account to use its AI models. Puter manages sign-in and usage authorization; ClassWire does not request or store a Puter API key.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Connect Puter account", systemImage: "person.crop.circle.badge.checkmark") {
                    showingPuterConnect = true
                    Task { await puterService.signIn(); await store.refreshKeyStatus() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onChange(of: puterService.isSignedIn) { _, isSignedIn in
            Task {
                await store.refreshKeyStatus()
                if isSignedIn {
                    showingPuterConnect = false
                }
            }
        }
    }

    private var apiKeyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            SecureField("API key", text: $keyInput)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
                .autocorrectionDisabled()

            HStack(spacing: 8) {
                if store.hasSavedProviderKey {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.secondary)
                    Text("A key is saved in Keychain")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Button("Remove", role: .destructive) {
                        store.removeProviderKey()
                        keyInput = ""
                        keyStatus = "Saved key removed from Keychain."
                    }
                } else {
                    Image(systemName: "key")
                        .foregroundStyle(.orange)
                    Text("No API key saved")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    Spacer(minLength: 4)
                }
            }

            Button("Save API key", systemImage: "lock.fill", action: saveKey)
                .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)
        }
    }

    private var ollamaControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Ollama server URL", text: $store.ollamaEndpoint)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
                .autocorrectionDisabled()
            Text("On iPhone and iPad, use the Mac or computer's LAN address (for example, http://192.168.1.20:11434). 127.0.0.1 refers to the device itself.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var keyStatusMessage: some View {
        if !keyStatus.isEmpty {
            if keyStatus.localizedCaseInsensitiveContains("could not") {
                Text(keyStatus)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text(keyStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var googleCloudSection: some View {
        Section("Google Gemini") {
            if store.googleAccountEmail.isEmpty {
                Text("Connect your Google account. ClassWire will automatically create or reuse a Google Cloud project named ClassWire AI, enable the required services, and create or reuse a Gemini API key.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Connect Google and set up Gemini", systemImage: "person.crop.circle.badge.checkmark") {
                    Task { await store.configureGeminiAutomatically() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isConnectingGoogle || store.isCreatingGeminiKey)
            } else {
                Label("Connected as \(store.googleAccountEmail)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                if store.hasSavedProviderKey {
                    Label("Gemini is configured on this device", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                Button("Set up or repair Gemini automatically", systemImage: "arrow.clockwise") {
                    Task { await store.configureGeminiAutomatically() }
                }
                .disabled(store.isConnectingGoogle || store.isCreatingGeminiKey)
                NavigationLink("Advanced Gemini settings", destination: ClassWireGeminiAdvancedSettingsView(store: store))
            }

            if store.isConnectingGoogle || store.isCreatingGeminiKey {
                ProgressView("Setting up Gemini…")
            }
            if !store.googleStatus.isEmpty {
                Text(store.googleStatus)
                    .font(.footnote)
                    .foregroundStyle(
                        store.googleStatus.localizedCaseInsensitiveContains("failed") ||
                        store.googleStatus.localizedCaseInsensitiveContains("could not") ||
                        store.googleStatus.localizedCaseInsensitiveContains("error")
                        ? .red : .secondary
                    )
                    .textSelection(.enabled)
            }
            Text("Google may require permission to create projects, enable APIs, and manage API keys. Google Cloud billing or account restrictions may prevent automatic setup. Your Gemini key is stored in Apple Keychain.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
        Section("Privacy and security") {
            Label("API keys and Google refresh tokens are stored in Apple Keychain.", systemImage: "lock.shield")
            Text("Puter authentication remains in its WebKit website session and is not copied into ClassWire settings or Keychain.")
            Text("Your prompts and the Schoology information needed to answer them are sent directly to the AI provider you select. ClassWire does not store provider keys in conversation history or UserDefaults.")
            Text("Conversation history is saved locally on this device. Avoid asking AI to process information you do not want sent to your selected provider.")
        }
    }

    private func saveKey() {
        do {
            try store.saveProviderKey(keyInput)
            keyInput = ""
            keyStatus = "API key saved securely in Keychain."
        } catch {
            keyStatus = "Could not save API key: \(error.localizedDescription)"
        }
    }
}
