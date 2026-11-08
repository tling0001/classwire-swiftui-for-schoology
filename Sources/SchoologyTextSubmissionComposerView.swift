import SwiftUI

struct SchoologyTextSubmissionComposerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    private enum FocusedField: Hashable { case submission, comment }
    @FocusState private var focusedField: FocusedField?

    let sectionID: String
    let context: SchoologyAssignmentContext
    let onSubmitted: () -> Void

    @State private var text = ""
    @State private var saveAsDraft = false
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var comment = ""
    @State private var submissionCreated = false
    @State private var isShowingLinkPrompt = false

    @State private var formattedText = AttributedString("")
    @available(iOS 26.0, macOS 26.0, *)
    @State private var formattedSelection = AttributedTextSelection()

    private var submissionText: String {
        if #available(iOS 26.0, macOS 26.0, *) {
            return String(formattedText.characters)
        }
        return text
    }

    private var submissionBody: String {
        if #available(iOS 26.0, macOS 26.0, *) {
            return SchoologySubmissionHTML.encode(formattedText, fontContext: fontResolutionContext)
        }
        return text
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Submission") {
                    submissionEditor
                }
                Section {
                    Toggle("Save as draft", isOn: $saveAsDraft)
                }
                Section("Comment (Optional)") {
                    TextField("Add a comment…", text: $comment, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($focusedField, equals: .comment)
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.red).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Text Submission")
            .sheet(isPresented: $isShowingLinkPrompt) {
                if #available(iOS 26.0, macOS 26.0, *) {
                    SchoologyInsertLinkSheet(text: $formattedText, selection: $formattedSelection) { message in error = message }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    #if os(iOS)
                    if focusedField != nil {
                        SchoologyKeyboardDoneToolbarButton { focusedField = nil }
                    } else if submissionCreated {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Submit", systemImage: "paperplane.fill", action: submit)
                            .disabled(isSubmitting || submissionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    #else
                    if submissionCreated {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Submit", systemImage: "paperplane.fill", action: submit)
                            .disabled(isSubmitting || submissionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    #endif
                }
            }
        }
        #if os(iOS)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if #available(iOS 26.0, *), focusedField == .submission {
                formattingBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        #endif
    }

    @ViewBuilder
    private var submissionEditor: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            VStack(alignment: .leading, spacing: 10) {
                richTextEditor
                #if os(iOS)
                if focusedField != .submission {
                    formattingBar
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                #else
                formattingBar
                    .frame(maxWidth: .infinity, alignment: .center)
                #endif
            }
        } else {
            TextEditor(text: $text)
                .frame(minHeight: 220)
                .accessibilityLabel("Enter your submission")
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private var formattingBar: some View {
        SchoologySubmissionFormattingBar(
            text: $formattedText,
            selection: $formattedSelection,
            onInsertLink: {
                isShowingLinkPrompt = true
            }
        )
    }

    @available(iOS 26.0, macOS 26.0, *)
    private var richTextEditor: some View {
        #if os(iOS)
        TextEditor(text: $formattedText, selection: $formattedSelection)
            .frame(minHeight: 220)
            .textInputFormattingControlVisibility(.hidden, for: .default)
            .focused($focusedField, equals: .submission)
            .accessibilityLabel("Enter your submission")
        #else
        TextEditor(text: $formattedText, selection: $formattedSelection)
            .frame(minHeight: 220)
            .focused($focusedField, equals: .submission)
            .accessibilityLabel("Enter your submission")
        #endif
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        Task {
            do {
                try await session.submitAssignmentText(
                    sectionID: sectionID,
                    gradeItemID: context.gradeItemID,
                    text: submissionBody,
                    draft: saveAsDraft
                )
                submissionCreated = true
                onSubmitted()
                let commentBody = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                if !commentBody.isEmpty {
                    do {
                        try await session.postAssignmentComment(
                            sectionID: sectionID,
                            assignmentID: context.assignment.id,
                            body: commentBody
                        )
                    } catch {
                        self.error = "Your submission was created, but its comment could not be posted: \(error.localizedDescription)"
                        isSubmitting = false
                        return
                    }
                }
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
