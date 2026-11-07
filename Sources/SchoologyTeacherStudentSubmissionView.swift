import SwiftUI

struct SchoologyTeacherStudentSubmissionView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    let sectionID: String
    let gradeItemID: String
    let student: SchoologyAssignmentStudent
    let maxPoints: String
    let onSaved: () -> Void

    @State private var profile: SchoologyProfileItem?
    @State private var revisions: [SchoologyAssignmentRevision] = []
    @State private var grade = ""
    @State private var comment = ""
    @State private var commentVisible = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var saveConfirmation: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading student submission…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            studentHeader

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Submissions").font(.headline)
                                if revisions.isEmpty {
                                    ContentUnavailableView("No submissions", systemImage: "doc.text",
                                        description: Text("This student hasn't submitted any revisions yet."))
                                        .frame(minHeight: 150)
                                } else {
                                    ForEach(revisions) { revision in
                                        revisionCard(revision)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Grade").font(.headline)
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    TextField("Grade", text: $grade)
                                        #if os(iOS)
                                        .keyboardType(.decimalPad)
                                        #endif
                                    if !maxPoints.isEmpty {
                                        Text("/ " + SchoologyGradeValueFormatter.display(maxPoints))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(12)
                                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                                Text("Overall Comment").font(.headline)
                                TextField("Write an overall comment…", text: $comment, axis: .vertical)
                                    .lineLimit(4...10)
                                    .padding(10)
                                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
                                Toggle("Display comment to student", isOn: $commentVisible)
                            }
                            .padding(14)
                            .background(.quaternary.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))

                            if let saveConfirmation {
                                Label(saveConfirmation, systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                            if let error {
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Grade Submission")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Grade", systemImage: "checkmark") {
                        Task { await saveGrade() }
                    }
                    .disabled(isLoading || isSaving || (!grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Double(grade) == nil))
                }
            }
            .task(id: student.id) { await load() }
        }
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 680, minHeight: 600, idealHeight: 760)
        #endif
    }

    private var studentHeader: some View {
        HStack(spacing: 12) {
            if let picture = profile?.pictureURL {
                AuthenticatedSchoologyImage(url: picture)
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            } else {
                SchoologyAvatarPlaceholder(size: 54, tint: SchoologyStyle.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.title ?? student.name)
                    .font(.title3.bold())
                Text(student.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(SchoologyGradeValueFormatter.display(grade.isEmpty ? student.grade : grade))
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private func revisionCard(_ revision: SchoologyAssignmentRevision) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Revision \(revision.id)").font(.subheadline.bold())
                Spacer()
                Text(revision.status)
                    .font(.caption)
                    .foregroundStyle(revision.status == "Late" ? .orange : .secondary)
            }
            if !revision.created.isEmpty {
                Text(SchoologyValue.date(revision.created)?.formatted(date: .abbreviated, time: .shortened) ?? revision.created)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !revision.body.isEmpty {
                SchoologyRichTextText(revision.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !revision.attachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(revision.attachments) { attachment in
                        SchoologyAttachmentPreviewButton(attachment: attachment)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
    }

    private func load() async {
        isLoading = true
        error = nil
        async let profileRequest = try? await session.loadPersonProfile(userID: student.id)
        async let gradeRequest = try? await session.loadTeacherAssignmentGrade(
            sectionID: sectionID,
            assignmentID: gradeItemID,
            enrollmentID: student.enrollmentID
        )
        async let revisionRequest = try? await session.loadTeacherAssignmentRevisions(
            sectionID: sectionID,
            gradeItemID: gradeItemID,
            userID: student.id
        )
        profile = await profileRequest
        if let gradeData = await gradeRequest {
            grade = gradeData.grade
            comment = gradeData.comment
            commentVisible = gradeData.commentVisible
        }
        revisions = (await revisionRequest) ?? []
        if profile == nil && revisions.isEmpty {
            error = "ClassWire couldn't load this student's profile or submission details."
        }
        isLoading = false
    }

    private func saveGrade() async {
        guard !isSaving else { return }
        isSaving = true
        error = nil
        saveConfirmation = nil
        do {
            try await session.updateTeacherAssignmentGrade(
                sectionID: sectionID,
                assignmentID: gradeItemID,
                enrollmentID: student.enrollmentID,
                grade: grade,
                comment: comment,
                commentVisible: commentVisible
            )
            saveConfirmation = "Grade saved"
            onSaved()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
