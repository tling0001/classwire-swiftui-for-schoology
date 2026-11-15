import SwiftUI
import UniformTypeIdentifiers

enum GroupProfileAction: String, Identifiable {
    case update, discussion, event, album, resource
    var id: String { rawValue }
    var title: String {
        switch self {
        case .update: "Post update"
        case .discussion: "Create discussion"
        case .event: "Create event"
        case .album: "Create album"
        case .resource: "Add resource"
        }
    }
}

struct GroupProfileActionSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let groupID: String
    let action: GroupProfileAction
    let onComplete: () -> Void
    @State private var title = ""
    @State private var resourceID = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if action == .album {
                    Section("Album") {
                        TextField("Album name", text: $title)
                    }
                } else if action == .resource {
                    Section("Resource") {
                        TextField("Resource ID", text: $resourceID)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("Enter the resource ID provided by your learning platform. The app does not guess or create resource IDs.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(action.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await submit() } }
                        .disabled(isSubmitting || !canSubmit)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
        .presentationDetents([.medium, .large])
    }

    private var canSubmit: Bool {
        switch action {
        case .album:
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .resource:
            !resourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .update, .discussion, .event:
            false
        }
    }

    @MainActor
    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            switch action {
            case .album:
                try await session.createGroupAlbum(groupID: groupID, title: title)
            case .resource:
                try await session.addGroupResource(groupID: groupID, resourceID: resourceID)
            case .update, .discussion, .event:
                return
            }
            dismiss()
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
