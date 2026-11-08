import SwiftUI

struct SchoologyTextSubmissionComposerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @FocusState private var isSubmissionFocused: Bool

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
    @State private var linkText = ""
    @State private var linkAddress = ""

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
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.red).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Text Submission")
            .sheet(isPresented: $isShowingLinkPrompt) {
                linkPrompt
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if submissionCreated {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Submit", systemImage: "paperplane.fill", action: submit)
                            .disabled(isSubmitting || submissionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var submissionEditor: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            VStack(alignment: .leading, spacing: 10) {
                richTextEditor
                SchoologySubmissionFormattingBar(
                    text: $formattedText,
                    selection: $formattedSelection,
                    onInsertLink: {
                        linkText = ""
                        linkAddress = ""
                        isShowingLinkPrompt = true
                    }
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
        } else {
            TextEditor(text: $text)
                .frame(minHeight: 220)
                .accessibilityLabel("Enter your submission")
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private var richTextEditor: some View {
        #if os(iOS)
        TextEditor(text: $formattedText, selection: $formattedSelection)
            .frame(minHeight: 220)
            .textInputFormattingControlVisibility(.hidden, for: .default)
            .focused($isSubmissionFocused)
            .accessibilityLabel("Enter your submission")
        #else
        TextEditor(text: $formattedText, selection: $formattedSelection)
            .frame(minHeight: 220)
            .focused($isSubmissionFocused)
            .accessibilityLabel("Enter your submission")
        #endif
    }

    private var linkPrompt: some View {
        NavigationStack {
            Form {
                TextField("Text", text: $linkText)
                #if os(iOS)
                    .textInputAutocapitalization(.sentences)
                #endif
                TextField("Link", text: $linkAddress)
                #if os(iOS)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                #endif
            }
            .navigationTitle("Add Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isShowingLinkPrompt = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") { applyLink() }
                        .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  linkAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, idealWidth: 420)
        .schoologyFittedSheet()
        #endif
    }

    private func applyLink() {
        let label = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        var value = linkAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, !value.isEmpty else { return }
        if !value.contains("://") && !value.lowercased().hasPrefix("mailto:") {
            value = "https://" + value
        }
        guard let url = URL(string: value),
              ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? ""),
              url.scheme?.lowercased() == "mailto" || url.host != nil else {
            error = "Enter a valid web or email link."
            return
        }
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        var linkedText = AttributedString(label)
        linkedText.link = url
        formattedText.replaceSelection(&formattedSelection, with: linkedText)
        isShowingLinkPrompt = false
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
