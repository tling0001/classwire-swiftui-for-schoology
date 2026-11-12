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
    @Environment(\.fontResolutionContext) private var fontResolutionContext
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
    @State private var formattedMessage = AttributedString("")
    @available(iOS 26.0, macOS 26.0, *)
    @State private var formattedSelection = AttributedTextSelection()
    @State private var isShowingLinkPrompt = false
    @State private var isSending = false
    @State private var isUploading = false
    @State private var showingFileImporter = false
    @State private var showingResourcePicker = false
    @State private var fileIDs: [String] = []
    @State private var resourceIDs: [String] = []
    @State private var attachmentNames: [String] = []
    @State private var error: String?
    private var messageText: String {
        if #available(iOS 26.0, macOS 26.0, *) { return String(formattedMessage.characters) }
        return message
    }
    private var messageBody: String {
        if #available(iOS 26.0, macOS 26.0, *) {
            return session.isDemoMode ? String(formattedMessage.characters) : SchoologySubmissionHTML.encode(formattedMessage, fontContext: fontResolutionContext)
        }
        return message
    }

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
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            if #available(iOS 26.0, macOS 26.0, *) {
                                TextEditor(text: $formattedMessage, selection: $formattedSelection)
                                    .textInputFormattingControlVisibility(.hidden, for: .default)
                                    .focused($focusedField, equals: .message)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 132)
                            } else {
                                TextEditor(text: $message)
                                    .focused($focusedField, equals: .message)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 132)
                            }
                            if messageText.isEmpty {
                                Text("Write a message…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                        if #available(iOS 26.0, macOS 26.0, *), focusedField != .message { formattingBar }
                    }
                }
                SchoologyComposerMediaPicker(
                    isDisabled: isSending || isUploading,
                    onImagesPicked: uploadImages,
                    onError: { error = $0 },
                    onActivityChanged: { isUploading = $0 }
                )
                Section("Attachments") {
                    Button("File", systemImage: "paperclip") { showingFileImporter = true }
                        .disabled(isSending || isUploading)
                    Button("Schoology Resources", systemImage: "folder") { showingResourcePicker = true }
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
                            .disabled(isSending || isUploading || selectedRecipients.isEmpty || (reply == nil && subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    #else
                    Button("Send", systemImage: "paperplane.fill", action: send)
                        .disabled(isSending || isUploading || selectedRecipients.isEmpty || (reply == nil && subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        .sheet(isPresented: $isShowingLinkPrompt) {
            if #available(iOS 26.0, macOS 26.0, *) {
                SchoologyInsertLinkSheet(text: $formattedMessage, selection: $formattedSelection) { message in error = message }
            }
        }
        #if os(iOS)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if #available(iOS 26.0, *), focusedField == .message { formattingBar.padding(.horizontal, 12).padding(.vertical, 8) }
        }
        #endif
    }

    @available(iOS 26.0, macOS 26.0, *)
    private var formattingBar: some View {
        SchoologySubmissionFormattingBar(text: $formattedMessage, selection: $formattedSelection) { isShowingLinkPrompt = true }
    }

    @MainActor
    private func uploadImages(_ images: [SchoologyComposerImage]) async {
        guard !images.isEmpty else { return }
        error = nil
        do {
            for image in images {
                let id = try await session.uploadMessageFile(data: image.data, filename: image.filename, mime: image.mimeType)
                fileIDs.append(id)
                attachmentNames.append(image.filename)
            }
        } catch {
            error = error.localizedDescription
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
                    try await session.replyToMessage(messageID: reply.messageID, recipientID: reply.recipientID, subject: reply.subject, message: messageBody, fileIDs: fileIDs, resourceIDs: resourceIDs)
                } else {
                    try await session.sendMessage(recipientIDs: selectedRecipients.map(\.id), subject: subject, message: messageBody, fileIDs: fileIDs, resourceIDs: resourceIDs)
                }
                onSent()
                dismiss()
            } catch { self.error = error.localizedDescription }
            isSending = false
        }
    }
}
