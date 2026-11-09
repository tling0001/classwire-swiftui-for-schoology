import SwiftUI

struct ClassWireAISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: ClassWireAIAssistantStore
    @State private var keyInput = ""
    @State private var keyStatus = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("AI provider") {
                    Picker("Provider", selection: $store.provider) {
                        ForEach(ClassWireAIProvider.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }

                    TextField("Model", text: $store.model)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()

                    if store.provider.requiresAPIKey {
                        SecureField("API key", text: $keyInput)
#if os(iOS)
                            .textInputAutocapitalization(.never)
#endif
                            .autocorrectionDisabled()
                        HStack {
                            Label(
                                store.hasSavedProviderKey ? "A key is saved in Keychain" : "No API key saved",
                                systemImage: store.hasSavedProviderKey ? "checkmark.shield.fill" : "key"
                            )
                            .font(.footnote)
                            .foregroundStyle(store.hasSavedProviderKey ? .secondary : .orange)
                            Spacer()
                            if store.hasSavedProviderKey {
                                Button("Remove", role: .destructive) {
                                    store.removeProviderKey()
                                    keyInput = ""
                                    keyStatus = "Saved key removed from Keychain."
                                }
                            }
                        }
                        Button("Save API key", systemImage: "lock.fill", action: saveKey)
                            .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)
                    } else {
                        TextField("Ollama server URL", text: $store.ollamaEndpoint)
#if os(iOS)
                            .textInputAutocapitalization(.never)
#endif
                            .autocorrectionDisabled()
                        Text("On iPhone and iPad, use the Mac or computer's LAN address (for example, http://192.168.1.20:11434). 127.0.0.1 refers to the device itself.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !keyStatus.isEmpty {
                        Text(keyStatus)
                            .font(.footnote)
                            .foregroundStyle(keyStatus.localizedCaseInsensitiveContains("could not") ? .red : .secondary)
                    }
                }

                Section("Privacy and security") {
                    Label("API keys are stored in Apple Keychain on this device.", systemImage: "lock.shield")
                    Text("Your prompts and the Schoology information needed to answer them are sent directly to the AI provider you select. ClassWire does not store provider keys in conversation history or UserDefaults.")
                    Text("Conversation history is saved locally on this device. Avoid asking AI to process information you do not want sent to your selected provider.")
                    if store.provider == .gemini {
                        Text("Google account sign-in and automatic Gemini key creation are not part of this initial native port. You can paste a Gemini API key here; native Google Cloud OAuth provisioning can be added once the app's native OAuth client and callback are configured.")
                    }
                }
            }
            .navigationTitle("AI Settings")
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
            .onChange(of: store.model) { _, _ in store.persistSettings() }
            .onChange(of: store.ollamaEndpoint) { _, _ in store.persistSettings() }
            .task { await store.refreshKeyStatus() }
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
