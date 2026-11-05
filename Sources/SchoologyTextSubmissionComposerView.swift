import SwiftUI
struct SchoologyTextSubmissionComposerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let sectionID: String
    let context: SchoologyAssignmentContext
    let onSubmitted: () -> Void
    @State private var text = ""
    @State private var saveAsDraft = false
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var comment = ""
    @State private var submissionCreated = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Submission") { TextField("Enter your submission…", text: $text, axis: .vertical).lineLimit(8...18) }
                Section { Toggle("Save as draft", isOn: $saveAsDraft) }
                Section("Comment (Optional)") {
                    TextField("Add a comment…", text: $comment, axis: .vertical)
                        .lineLimit(2...5)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Text Submission")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSubmitting) }
                ToolbarItem(placement: .confirmationAction) {
                    if submissionCreated {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Submit", systemImage: "paperplane.fill", action: submit)
                            .disabled(isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        Task {
            do {
                try await session.submitAssignmentText(sectionID: sectionID, gradeItemID: context.gradeItemID, text: text, draft: saveAsDraft)
                submissionCreated = true
                onSubmitted()
                let commentBody = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                if !commentBody.isEmpty {
                    do {
                        try await session.postAssignmentComment(sectionID: sectionID, assignmentID: context.assignment.id, body: commentBody)
                    } catch {
                        self.error = "Your submission was created, but its comment could not be posted: \(error.localizedDescription)"
                        isSubmitting = false
                        return
                    }
                }
                dismiss()
            } catch { self.error = error.localizedDescription }
            isSubmitting = false
        }
    }
}
