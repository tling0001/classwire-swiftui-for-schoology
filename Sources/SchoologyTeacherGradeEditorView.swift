import SwiftUI

struct SchoologyTeacherGradeEditorView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let sectionID: String
    let assignmentID: String
    let enrollmentID: String
    let studentName: String
    let maxPoints: String
    let onSaved: () -> Void
    @State private var grade = ""
    @State private var comment = ""
    @State private var commentVisible = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Student") {
                    LabeledContent("Name", value: studentName)
                    HStack {
                        TextField("Grade", text: $grade)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        if !maxPoints.isEmpty {
                            Text("/ " + SchoologyGradeValueFormatter.display(maxPoints)).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Overall Comment") {
                    TextField("Comment", text: $comment, axis: .vertical).lineLimit(4...10)
                    Toggle("Display comment to student", isOn: $commentVisible)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Edit Grade")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isLoading || isSaving || (!grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Double(grade) == nil))
                }
            }
            .task { await load() }
            .overlay {
                if isLoading { ProgressView("Loading grade…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) }
            }
        }
    }

    private func load() async {
        do {
            let value = try await session.loadTeacherAssignmentGrade(sectionID: sectionID, assignmentID: assignmentID, enrollmentID: enrollmentID)
            grade = value.grade
            comment = value.comment
            commentVisible = value.commentVisible
        } catch { error = error.localizedDescription }
        isLoading = false
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        error = nil
        do {
            try await session.updateTeacherAssignmentGrade(sectionID: sectionID, assignmentID: assignmentID, enrollmentID: enrollmentID,
                grade: grade, comment: comment, commentVisible: commentVisible)
            onSaved()
            dismiss()
        } catch { error = error.localizedDescription }
        isSaving = false
    }
}
