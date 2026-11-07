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
    @State private var bodyText = ""
    @State private var resourceID = ""
    @State private var eventDate = Date()
    @State private var allDay = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showingDiscussionFileImporter = false
    @State private var discussionAttachmentData: Data?
    @State private var discussionAttachmentName = ""
    @State private var discussionAttachmentMIME = ""

    var body: some View {
        NavigationStack {
            Form {
                if action == .update {
                    Section("Update") {
                        TextField("Write an update…", text: $bodyText, axis: .vertical).lineLimit(5...10)
                    }
                } else if action == .discussion {
                    Section("Discussion") {
                        TextField("Title", text: $title)
                        TextField("Description", text: $bodyText, axis: .vertical).lineLimit(4...8)
                        if session.isDemoMode {
                            Button {
                                showingDiscussionFileImporter = true
                            } label: {
                                Label(discussionAttachmentName.isEmpty ? "Attach a file" : discussionAttachmentName,
                                      systemImage: "paperclip")
                            }
                            if !discussionAttachmentName.isEmpty {
                                Button("Remove attachment", role: .destructive) {
                                    discussionAttachmentData = nil
                                    discussionAttachmentName = ""
                                    discussionAttachmentMIME = ""
                                }
                            }
                            Text("Attachments are stored only in this demo session.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } else if action == .event {
                    Section("Event") {
                        TextField("Title", text: $title)
                        TextField("Description", text: $bodyText, axis: .vertical).lineLimit(3...6)
                        DatePicker("Starts", selection: $eventDate, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                        Toggle("All day", isOn: $allDay)
                    }
                } else if action == .album {
                    Section("Album") { TextField("Album name", text: $title) }
                } else {
                    Section("Resource") {
                        TextField("Resource ID", text: $resourceID)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("Enter the resource ID provided by your learning platform. The app does not guess or create resource IDs.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(action.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { Task { await submit() } }
                        .disabled(isSubmitting || !canSubmit)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
        .presentationDetents([.medium, .large])
        .fileImporter(isPresented: $showingDiscussionFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                discussionAttachmentData = try Data(contentsOf: url)
                discussionAttachmentName = url.lastPathComponent
                discussionAttachmentMIME = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            } catch {
                errorMessage = "Could not read the attachment: \(error.localizedDescription)"
            }
        }
    }

    private var canSubmit: Bool {
        switch action {
        case .update: !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .discussion, .event, .album: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .resource: !resourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @MainActor
    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            switch action {
            case .update:
                try await session.createGroupUpdate(groupID: groupID, body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines))
            case .discussion:
                try await session.createGroupDiscussion(groupID: groupID, title: title, body: bodyText,
                    attachmentData: discussionAttachmentData, attachmentFilename: discussionAttachmentName,
                    attachmentMIME: discussionAttachmentMIME)
            case .event:
                try await session.createGroupEvent(groupID: groupID, title: title, description: bodyText, start: eventDate, allDay: allDay)
            case .album:
                try await session.createGroupAlbum(groupID: groupID, title: title)
            case .resource:
                try await session.addGroupResource(groupID: groupID, resourceID: resourceID)
            }
            dismiss()
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
