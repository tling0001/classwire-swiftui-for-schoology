import SwiftUI

struct SchoologyResourceAppPickerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    let app: SchoologyResourceCollection
    let onAdd: ([SchoologyPickedResource]) -> Void

    @State private var launchURL: URL?
    @State private var imported: [SchoologyPickedResource]?
    @State private var selectedIDs: Set<String> = []
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let imported {
                    if imported.isEmpty {
                        ContentUnavailableView(
                            "No imported resources",
                            systemImage: "doc",
                            description: Text("The resource app did not return any files or links to import.")
                        )
                    } else {
                        List {
                            Section("Imported from \(app.title)") {
                                ForEach(imported) { resource in
                                    Button {
                                        toggleSelection(resource)
                                    } label: {
                                        HStack {
                                            Label(resource.title, systemImage: "doc")
                                            Spacer()
                                            if selectedIDs.contains(resource.id) {
                                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .schoologyInsetGroupedListStyle()
                    }
                } else if isLoading {
                    ProgressView("Opening \(app.title)…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isImporting {
                    ProgressView("Importing resources…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let launchURL {
                    SchoologyEmbeddedWebView(
                        url: launchURL,
                        title: app.title,
                        onResourceImport: { importURL in
                            Task { await importResources(from: importURL) }
                        }
                    )
                } else if let error {
                    ContentUnavailableView(
                        "Unable to open resource app",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                }
            }
            .navigationTitle(app.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if imported != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let selected = imported?.filter { selectedIDs.contains($0.id) } ?? []
                            onAdd(selected)
                            dismiss()
                        }
                        .disabled(selectedIDs.isEmpty)
                    }
                }
            }
            .alert("Unable to import resources", isPresented: Binding(
                get: { error != nil && launchURL != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK", role: .cancel) { error = nil }
            } message: {
                Text(error ?? "")
            }
            .task(id: app.id) { await launch() }
        }
    }

    private func toggleSelection(_ resource: SchoologyPickedResource) {
        if selectedIDs.contains(resource.id) {
            selectedIDs.remove(resource.id)
        } else {
            selectedIDs.insert(resource.id)
        }
    }

    @MainActor
    private func launch() async {
        isLoading = true
        error = nil
        do {
            launchURL = try await session.launchResourceApp(app)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func importResources(from url: URL) async {
        guard !isImporting else { return }
        isImporting = true
        error = nil
        defer { isImporting = false }
        do {
            let resources = try await session.importResourceAppItems(from: url)
            imported = resources
            selectedIDs = Set(resources.map(\.id))
        } catch {
            self.error = error.localizedDescription
        }
    }
}
