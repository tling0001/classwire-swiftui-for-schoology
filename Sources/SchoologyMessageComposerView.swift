import SwiftUI
struct SchoologyMessageComposerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let onSent: () -> Void
    @State private var recipientQuery = ""
    @State private var recipients: [SchoologyMessageRecipient] = []
    @State private var selectedRecipients: [SchoologyMessageRecipient] = []
    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("To") {
                    TextField("Search recipients", text: $recipientQuery)
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
                Section("Message") {
                    TextField("Subject", text: $subject)
                    TextField("Write a message…", text: $message, axis: .vertical).lineLimit(6...16)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSending) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", systemImage: "paperplane.fill", action: send)
                        .disabled(isSending || selectedRecipients.isEmpty || subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task(id: recipientQuery) {
                let query = recipientQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard query.count >= 2 else { recipients = []; return }
                do {
                    try await Task.sleep(nanoseconds: 250_000_000)
                    try Task.checkCancellation()
                    recipients = try await session.searchMessageRecipients(query)
                } catch is CancellationError { return }
                catch { self.error = error.localizedDescription }
            }
        }
    }
    private func send() {
        guard !isSending else { return }
        isSending = true
        error = nil
        Task {
            do {
                try await session.sendMessage(recipientIDs: selectedRecipients.map(\.id), subject: subject, message: message)
                onSent()
                dismiss()
            } catch { self.error = error.localizedDescription }
            isSending = false
        }
    }
}
