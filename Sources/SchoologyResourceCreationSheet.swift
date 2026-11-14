import SwiftUI

enum SchoologyResourceCreationMode: String, Identifiable {
    case collection
    case resource
    var id: String { rawValue }
}

struct SchoologyResourceCreationSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    let mode: SchoologyResourceCreationMode
    let collections: [SchoologyResourceCollection]
    var preferredCollectionID: String? = nil
    let onCreated: () async -> Void

    @State private var selectedCollectionID = ""
    @State private var resourceType = "page"
    @State private var title = ""
    @State private var bodyText = ""
    @State private var notes = ""
    @State private var linkURL = ""
    @State private var maxPoints = 100
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if mode == .collection { return true }
        guard collections.contains(where: { $0.id == selectedCollectionID }) else { return false }
        if resourceType == "document" {
            guard let url = URL(string: linkURL.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
            return ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                if mode == .resource {
                    Section("Destination") {
                        Picker("Collection", selection: $selectedCollectionID) {
                            ForEach(collections) { collection in
                                Text(collection.title).tag(collection.id)
                            }
                        }
                        .disabled(preferredCollectionID != nil)
                    }
                    Section("Resource") {
                        Picker("Type", selection: $resourceType) {
                            Text("Page").tag("page")
                            Text("Discussion").tag("discussion")
                            Text("Assignment").tag("assignment")
                            Text("Document link").tag("document")
                        }
                        TextField("Title", text: $title)
                        if resourceType != "document" {
                            TextField("Description", text: $bodyText, axis: .vertical)
                                .lineLimit(4...9)
                        } else {
                            TextField("Web address", text: $linkURL)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                #endif
                        }
                        if resourceType == "assignment" {
                            Stepper("Maximum points: \(maxPoints)", value: $maxPoints, in: 0...10000)
                        }
                    }
                    Section("Notes") {
                        TextField("Resource notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                    }
                    if resourceType == "document" {
                        Section {
                            Text("This creates a Schoology document containing a web link. File uploads and embedded documents are not included in this form.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section("Collection") {
                        TextField("Collection name", text: $title)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode == .collection ? "New Collection" : "New Resource")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Creating…" : "Create") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .task {
                if let preferredCollectionID {
                    selectedCollectionID = preferredCollectionID
                } else if selectedCollectionID.isEmpty {
                    selectedCollectionID = collections.first?.id ?? ""
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            if mode == .collection {
                try await session.createResourceCollection(title: title)
            } else {
                try await session.createResourceTemplate(
                    collectionID: selectedCollectionID,
                    title: title,
                    type: resourceType,
                    body: bodyText,
                    notes: notes,
                    linkURL: linkURL,
                    maxPoints: maxPoints
                )
            }
            await onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
