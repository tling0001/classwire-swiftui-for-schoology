import SwiftUI

struct ClassWireGeminiAdvancedSettingsView: View {
    @Bindable var store: ClassWireAIAssistantStore

    var body: some View {
        Form {
            Section("Google account") {
                if store.googleAccountEmail.isEmpty {
                    ContentUnavailableView(
                        "Google is not connected",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Connect Google from the main AI Settings page to manage the ClassWire AI project.")
                    )
                } else {
                    LabeledContent("Account", value: store.googleAccountEmail)
                    if !store.googleProjects.isEmpty {
                        Picker("Project", selection: $store.selectedGoogleProjectID) {
                            ForEach(store.googleProjects) { project in
                                Text("\(project.displayName) · \(project.projectID)")
                                    .tag(project.projectID)
                            }
                        }
                        Button("Create or reuse key in selected project", systemImage: "key.horizontal") {
                            Task { await store.createGeminiKey(projectID: store.selectedGoogleProjectID) }
                        }
                        .disabled(store.selectedGoogleProjectID.isEmpty || store.isCreatingGeminiKey)
                    } else {
                        Text("No projects are loaded yet.")
                            .foregroundStyle(.secondary)
                    }
                    Button("Refresh project list", systemImage: "arrow.clockwise") {
                        Task { await store.refreshGoogleProjects() }
                    }
                    .disabled(store.isConnectingGoogle || store.isCreatingGeminiKey)
                    Button("Disconnect Google account", role: .destructive) {
                        store.disconnectGoogle()
                    }
                }
            }

            Section("Project and key management") {
                Text("The standard setup automatically creates or reuses a project named ClassWire AI. These advanced controls let you inspect other projects or explicitly create/reuse a Gemini key in a different project.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if store.isConnectingGoogle || store.isCreatingGeminiKey {
                    ProgressView("Working with Google Cloud…")
                }
                if !store.googleStatus.isEmpty {
                    Text(store.googleStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Advanced Gemini")
        .task {
            if !store.googleAccountEmail.isEmpty && store.googleProjects.isEmpty {
                await store.refreshGoogleProjects()
            }
        }
    }
}
