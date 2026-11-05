import SwiftUI
struct SchoologyAssignmentSubmissionView: View {
    @Environment(AppSession.self) private var session
    let sectionID: String
    let context: SchoologyAssignmentContext
    @State private var summary: SchoologyAssignmentSubmissionSummary?
    @State private var loading = true
    @State private var error: String?
    @Binding var showingTextComposer: Bool
    @State private var selectedStudent: SchoologyAssignmentStudent?
    @Binding var refreshID: UUID
    var body: some View {
        Group {
            if loading && summary == nil {
                ProgressView("Loading submissions…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, summary == nil {
                ContentUnavailableView("Unable to load submissions", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if let summary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(context.isTeacher ? "Student Submissions" : "Your Submissions").font(.headline)
                        if context.isTeacher {
                            if summary.students.isEmpty { ContentUnavailableView("No students found", systemImage: "person.2") }
                            else {
                                VStack(spacing: 0) {
                                    ForEach(summary.students) { student in
                                        Button {
                                            selectedStudent = student
                                        } label: {
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(student.name).font(.subheadline.weight(.semibold))
                                                    Text(student.status).font(.caption).foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                Text(SchoologyGradeValueFormatter.display(student.grade)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.vertical, 10)
                                        if student.id != summary.students.last?.id { Divider() }
                                    }
                                }
                                .padding(.horizontal, 14).background(.background, in: RoundedRectangle(cornerRadius: 12))
                            }
                        } else {
                            HStack {
                                Text("Grade").font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(SchoologyGradeValueFormatter.display(summary.grade))" +
                                    (context.maxPoints.isEmpty ? "" : " / \(SchoologyGradeValueFormatter.display(context.maxPoints))"))
                                    .font(.subheadline.monospacedDigit())
                            }
                            .padding(14).background(.background, in: RoundedRectangle(cornerRadius: 12))
                            if !summary.teacherComment.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Overall Comment").font(.subheadline.weight(.semibold))
                                    Text(summary.teacherComment).textSelection(.enabled)
                                }
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                            }
                            if summary.revisions.isEmpty {
                                ContentUnavailableView("No submissions yet", systemImage: "doc.text", description: Text("Your submitted work and revisions will appear here."))
                            } else {
                                ForEach(summary.revisions) { revision in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Revision \(revision.id)").font(.subheadline.bold())
                                            Spacer()
                                            Text(revision.status).font(.caption).foregroundStyle(.secondary)
                                        }
                                        if !revision.created.isEmpty { Text(revision.created).font(.caption).foregroundStyle(.secondary) }
                                        if !revision.body.isEmpty { SchoologyRichTextText(revision.body).textSelection(.enabled) }
                                        ForEach(revision.attachments) { attachment in SchoologyAttachmentPreviewButton(attachment: attachment) }
                                    }
                                    .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                    .padding().frame(maxWidth: 850).frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .refreshable { await load() }
            }
        }
        .task(id: refreshID) { await load() }
        .sheet(isPresented: $showingTextComposer) {
            SchoologyTextSubmissionComposerView(sectionID: sectionID, context: context) { refreshID = UUID() }
        }
        .sheet(item: $selectedStudent) { student in
            SchoologyTeacherStudentSubmissionView(
                sectionID: sectionID,
                gradeItemID: context.gradeItemID,
                student: student,
                maxPoints: context.maxPoints
            ) {
                refreshID = UUID()
            }
        }
    }
    private func load() async {
        guard context.canSubmit else { return }
        loading = true
        error = nil
        do { summary = try await session.loadAssignmentSubmissions(sectionID: sectionID, context: context) }
        catch { self.error = error.localizedDescription }
        loading = false
    }

}
