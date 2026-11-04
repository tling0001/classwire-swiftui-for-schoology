import SwiftUI
import UniformTypeIdentifiers
struct SchoologyAssignmentSubmissionView: View {
    @Environment(AppSession.self) private var session
    let sectionID: String
    let context: SchoologyAssignmentContext
    @State private var summary: SchoologyAssignmentSubmissionSummary?
    @State private var loading = true
    @State private var error: String?
    @Binding var showingTextComposer: Bool
    @Binding var showingFileImporter: Bool
    @Binding var showingResourcePicker: Bool
    @State private var selectedStudent: SchoologyAssignmentStudent?
    @State private var isUploading = false
    @State private var uploadCompletedCount = 0
    @State private var uploadTotalCount = 0
    @State private var uploadStatus = ""
    @State private var uploadError: String?
    @State private var refreshID = UUID()
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
                        if isUploading {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    ProgressView()
                                    Text(uploadStatus.isEmpty ? "Uploading and submitting files…" : uploadStatus)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: Double(uploadCompletedCount), total: Double(max(uploadTotalCount, 1)))
                                Text("\(uploadCompletedCount) of \(uploadTotalCount) files completed")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
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
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                guard !urls.isEmpty else { return }
                Task { await uploadSubmissions(from: urls) }
            case .failure(let error):
                uploadError = error.localizedDescription
            }
        }
        .alert("Unable to Submit File", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK", role: .cancel) { uploadError = nil }
        } message: {
            Text(uploadError ?? "The file could not be submitted.")
        }
        .sheet(isPresented: $showingTextComposer) {
            SchoologyTextSubmissionComposerView(sectionID: sectionID, context: context) { refreshID = UUID() }
        }
        .sheet(isPresented: $showingResourcePicker) {
            SchoologyResourcePickerView { resourceID, _ in
                Task {
                    isUploading = true
                    defer { isUploading = false }
                    do {
                        try await session.submitAssignmentResource(sectionID: sectionID, assignmentID: context.assignment.id, resourceID: resourceID)
                        await load()
                    } catch {
                        uploadError = error.localizedDescription
                    }
                }
            }
        }
        .sheet(item: $selectedStudent) { student in
            SchoologyTeacherGradeEditorView(sectionID: sectionID, assignmentID: context.gradeItemID,
                enrollmentID: student.enrollmentID, studentName: student.name, maxPoints: context.maxPoints) {
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

    private func uploadSubmissions(from urls: [URL]) async {
        guard !isUploading, !urls.isEmpty else { return }
        isUploading = true
        uploadCompletedCount = 0
        uploadTotalCount = urls.count
        uploadStatus = "Preparing files…"
        defer {
            isUploading = false
            uploadStatus = ""
        }
        var failures: [String] = []
        for (index, url) in urls.enumerated() {
            uploadStatus = "Uploading \(url.lastPathComponent)…"
            let didAccess = url.startAccessingSecurityScopedResource()
            do {
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                try await session.submitAssignmentFile(data: data, filename: url.lastPathComponent, mime: mime,
                    sectionID: sectionID, assignmentID: context.assignment.id)
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
            uploadCompletedCount = index + 1
        }
        await load()
        if !failures.isEmpty { uploadError = failures.joined(separator: "\n") }
    }
}
