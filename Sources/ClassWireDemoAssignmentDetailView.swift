import SwiftUI
import UniformTypeIdentifiers

struct ClassWireDemoAssignmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let assignment: ClassWireDemoAssignment
    let isTeacher: Bool

    @State private var selectedTab = "Info"
    @State private var comments = [
        "Ms. Rivera: Please show your work and label each section.",
        "Jordan Lee: I found the diagram in Unit 3."
    ]
    @State private var draftComment = ""
    @State private var submissionText = ""
    @State private var selectedFiles: [URL] = []
    @State private var showingFileImporter = false
    @State private var showingExternalToolInfo = false
    @Binding var isSubmitted: Bool
    @State private var teacherGrade = "18"
    @State private var teacherFeedback = "Good work. Add more detail to your explanation."
    @State private var teacherGradeSaved = false

    private var tabs: [String] {
        assignment.isExternalTool ? ["Info", "Comments"] : ["Info", "Comments", isTeacher ? "Submissions" : "Submission"]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Assignment section", selection: $selectedTab) {
                    ForEach(tabs, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()
                Group {
                    switch selectedTab {
                    case "Comments": commentsView
                    case "Submission", "Submissions": submissionView
                    default: infoView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(assignment.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    selectedFiles.append(contentsOf: urls)
                }
            }
            .alert("External learning tool", isPresented: $showingExternalToolInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This LTI activity normally launches its provider. The demo does not connect to external providers, and it does not show a native submission composer for this activity.")
            }
        }
    }

    private var infoView: some View {
        List {
            Section("Assignment") {
                LabeledContent("Course", value: assignment.course)
                LabeledContent("Due", value: assignment.due)
                LabeledContent("Points", value: assignment.isExternalTool ? "—" : "20")
                LabeledContent("Status", value: isSubmitted ? "Submitted (demo)" : assignment.status)
            }
            Section("Instructions") {
                Text(assignment.isExternalTool
                     ? "Complete the activity in the connected external learning tool. This sample represents an LTI assignment."
                     : "Review the lesson materials and complete the activity. Explain your reasoning and attach any supporting work.")
            }
            Section("Attachments") {
                Label("Assignment instructions.pdf", systemImage: "doc.richtext")
                Label("Reference diagram.png", systemImage: "photo")
            }
            Section("Teacher feedback") {
                Text("Remember to include units and explain your answer.")
                    .foregroundStyle(.secondary)
            }
            if assignment.isExternalTool {
                Section("External activity") {
                    Label("LTI / external tool", systemImage: "app.connected.to.app.below.fill")
                    Button("Preview external tool information", systemImage: "arrow.up.right") {
                        showingExternalToolInfo = true
                    }
                }
            }
        }
    }

    private var commentsView: some View {
        VStack(spacing: 0) {
            List {
                Section("Comments") {
                    ForEach(comments, id: \.self) { comment in
                        Label(comment, systemImage: "text.bubble")
                            .textSelection(.enabled)
                    }
                }
            }
            HStack {
                TextField("Write a comment", text: $draftComment, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Post", systemImage: "paperplane.fill") {
                    let value = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty else { return }
                    comments.append("Alex Morgan: \(value)")
                    draftComment = ""
                }
                .disabled(draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
    }

    private var submissionView: some View {
        Form {
            if isTeacher {
                Section("Student submissions") {
                    ForEach(["Jordan Lee", "Avery Johnson", "Taylor Brooks"], id: \.self) { student in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(student).font(.headline)
                            Text("Submitted · November 9").font(.caption).foregroundStyle(.secondary)
                            Label("Response document.pdf", systemImage: "doc.richtext")
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Grade and feedback") {
                    TextField("Score", text: $teacherGrade)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Feedback", text: $teacherFeedback, axis: .vertical)
                    Button("Save sample grade", systemImage: "checkmark") { teacherGradeSaved = true }
                    if teacherGradeSaved {
                        Label("Saved locally: \(teacherGrade) / 20", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Text("Grade entry is simulated and does not change a real student record.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else if assignment.isExternalTool {
                ContentUnavailableView("External activity", systemImage: "app.connected.to.app.below.fill",
                                       description: Text("LTI activities launch their external provider and do not use the standard ClassWire submission composer."))
            } else {
                Section("Text submission") {
                    TextEditor(text: $submissionText)
                        .frame(minHeight: 130)
                    Text("Your text is saved only in this local demonstration.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("File attachments") {
                    Button("Choose files", systemImage: "paperclip") {
                        showingFileImporter = true
                    }
                    ForEach(selectedFiles, id: \.absoluteString) { file in
                        Label(file.lastPathComponent, systemImage: "doc")
                    }
                    if selectedFiles.isEmpty {
                        Text("No files attached").foregroundStyle(.secondary)
                    }
                }
                Section("Submit") {
                    if isSubmitted {
                        Label("Sample submission recorded", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Button("Undo sample submission", role: .destructive) { isSubmitted = false }
                    } else {
                        Button("Submit sample work", systemImage: "paperplane.fill") {
                            isSubmitted = true
                        }
                        .disabled(submissionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedFiles.isEmpty)
                    }
                    Text("This action is simulated. No file or coursework is sent to Schoology.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}
