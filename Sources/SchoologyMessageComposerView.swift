import SwiftUI
import UniformTypeIdentifiers
struct SchoologyMessageComposerView: View {
    struct ReplyContext: Identifiable, Hashable, Sendable {
        let messageID: String
        let recipientID: String
        let recipientName: String
        let subject: String
        var id: String { messageID }
    }

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    private enum FocusedField: Hashable { case recipientSearch, subject, message }
    @FocusState private var focusedField: FocusedField?
    let onSent: () -> Void
    let reply: ReplyContext?

    init(onSent: @escaping () -> Void, reply: ReplyContext? = nil) {
        self.onSent = onSent
        self.reply = reply
        _selectedRecipients = State(initialValue: reply.map {
            [SchoologyMessageRecipient(id: $0.recipientID, name: $0.recipientName)]
        } ?? [])
        _subject = State(initialValue: reply?.subject ?? "")
    }
    @State private var recipientQuery = ""
    @State private var recipients: [SchoologyMessageRecipient] = []
    @State private var selectedRecipients: [SchoologyMessageRecipient] = []
    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var isUploading = false
    @State private var showingFileImporter = false
    @State private var showingResourcePicker = false
    @State private var fileIDs: [String] = []
    @State private var resourceIDs: [String] = []
    @State private var attachmentNames: [String] = []
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                if let reply {
                    Section("To") { Label(reply.recipientName, systemImage: "person.crop.circle") }
                } else {
                    Section("To") {
                        TextField("Search recipients", text: $recipientQuery)
                            .focused($focusedField, equals: .recipientSearch)
                        ForEach(selectedRecipients) { recipient in
                            HStack {
                                Text(recipient.name)
                                Spacer()
                                Button("Remove", systemImage: "xmark.circle.fill") { selectedRecipients.removeAll { $0.id == recipient.id } }
                                    .labelStyle(.iconOnly).tint(.secondary)
                            }
                        }
                        ForEach(recipients.filter { candidate in !selectedRecipients.contains(where: { $0.id == candidate.id }) }) { recipient in
                            Button {
                                selectedRecipients.append(recipient)
                                recipientQuery = ""
                                recipients = []
                            } label: {
                                Label(recipient.name, systemImage: "person.crop.circle").foregroundStyle(.primary)
                            }
                        }
                        if !recipientQuery.isEmpty && recipientQuery.count < 2 {
                            Text("Enter at least two characters to search.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Message") {
                    if reply == nil {
                        TextField("Subject", text: $subject)
                            .focused($focusedField, equals: .subject)
                    }
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $message)
                            .focused($focusedField, equals: .message)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 132)
                        if message.isEmpty {
                            Text("Write a message…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                }
                Section("Attachments") {
                    Button("Attach File", systemImage: "paperclip") { showingFileImporter = true }
                        .disabled(isSending || isUploading)
                    Button("Attach Schoology Resource", systemImage: "folder") { showingResourcePicker = true }
                        .disabled(isSending || isUploading)
                    ForEach(Array(attachmentNames.enumerated()), id: \.offset) { _, name in
                        Label(name, systemImage: "paperclip").foregroundStyle(.secondary)
                    }
                    if isUploading { ProgressView("Uploading attachment…") }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle(reply == nil ? "New Message" : "Reply")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSending || isUploading) }
                ToolbarItem(placement: .confirmationAction) {
                    #if os(iOS)
                    if focusedField != nil {
                        SchoologyKeyboardDoneToolbarButton { focusedField = nil }
                    } else {
                        Button("Send", systemImage: "paperplane.fill", action: send)
                            .disabled(isSending || isUploading || selectedRecipients.isEmpty || (reply == nil && subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    #else
                    Button("Send", systemImage: "paperplane.fill", action: send)
                        .disabled(isSending || isUploading || selectedRecipients.isEmpty || (reply == nil && subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    #endif
                }
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true, onCompletion: importFiles)
            .sheet(isPresented: $showingResourcePicker) {
                SchoologyResourcePickerView { resources in
                    for resource in resources where !resourceIDs.contains(resource.id) {
                        resourceIDs.append(resource.id)
                        attachmentNames.append(resource.title)
                    }
                }
            }
            .task(id: recipientQuery) {
                let query = recipientQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard reply == nil, query.count >= 2 else { recipients = []; return }
                do {
                    try await Task.sleep(nanoseconds: 250_000_000)
                    try Task.checkCancellation()
                    recipients = try await session.searchMessageRecipients(query)
                } catch is CancellationError {
                    return
                } catch let error as URLError where error.code == .cancelled {
                    return
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let failure):
            error = failure.localizedDescription
        case .success(let urls):
            Task {
                isUploading = true
                error = nil
                defer { isUploading = false }
                do {
                    for url in urls {
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        let data = try Data(contentsOf: url)
                        let filename = url.lastPathComponent
                        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                        let id = try await session.uploadMessageFile(data: data, filename: filename, mime: mime)
                        fileIDs.append(id)
                        attachmentNames.append(filename)
                    }
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func send() {
        guard !isSending else { return }
        isSending = true
        error = nil
        Task {
            do {
                if let reply {
                    try await session.replyToMessage(messageID: reply.messageID, recipientID: reply.recipientID, subject: reply.subject, message: message, fileIDs: fileIDs, resourceIDs: resourceIDs)
                } else {
                    try await session.sendMessage(recipientIDs: selectedRecipients.map(\.id), subject: subject, message: message, fileIDs: fileIDs, resourceIDs: resourceIDs)
                }
                onSent()
                dismiss()
            } catch { self.error = error.localizedDescription }
            isSending = false
        }
    }
}
