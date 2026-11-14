import SwiftUI

struct SchoologyResourceEditSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    let item: SchoologyProfileItem
    let collectionID: String
    let onSaved: () async -> Void

    @State private var title: String
    @State private var bodyText: String
    @State private var notes: String
    @State private var folderColor: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(item: SchoologyProfileItem, collectionID: String, onSaved: @escaping () async -> Void) {
        self.item = item
        self.collectionID = collectionID
        self.onSaved = onSaved
        let raw = (try? JSONSerialization.jsonObject(with: item.rawJSON)) as? [String: Any] ?? [:]
        let fields = raw["template_fields"] as? [String: Any] ?? [:]
        _title = State(initialValue: item.title)
        _bodyText = State(initialValue: fields["body"] as? String ?? "")
        _notes = State(initialValue: raw["resource_notes"] as? String ?? "")
        _folderColor = State(initialValue: item.folderColor)
    }

    private var hasBody: Bool {
        let raw = (try? JSONSerialization.jsonObject(with: item.rawJSON)) as? [String: Any] ?? [:]
        let fields = raw["template_fields"] as? [String: Any] ?? [:]
        return fields["body"] != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Resource") {
                    TextField("Title", text: $title)
                    if hasBody {
                        TextField("Body", text: $bodyText, axis: .vertical).lineLimit(5...12)
                    }
                    TextField("Resource notes", text: $notes, axis: .vertical).lineLimit(2...6)
                }
                if item.isFolder {
                    Section("Folder appearance") {
                        Picker("Color", selection: $folderColor) {
                            ForEach(["blue", "pink", "orange", "purple", "yellow", "red", "gray", "black", "green"], id: \.self) {
                                Text($0.capitalized).tag($0)
                            }
                        }
                    }
                }
                Section {
                    Label("Existing attachments are retained when you save.", systemImage: "paperclip")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(item.isFolder ? "Edit Folder" : "Edit Resource")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await session.updateResourceTemplate(
                collectionID: collectionID, item: item, title: title,
                body: bodyText, notes: notes, folderColor: folderColor
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
