import SwiftUI
import UniformTypeIdentifiers
struct SchoologyAssignmentSubmissionView: View {
    @Environment(AppSession.self) private var session
    let sectionID: String
    let context: SchoologyAssignmentContext
    @State private var summary: SchoologyAssignmentSubmissionSummary?
    @State private var loading = true
    @State private var error: String?
    @State private var showingTextComposer = false
    @State private var showingFileImporter = false
    @State private var isUploading = false
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
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Uploading and submitting file…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(student.name).font(.subheadline.weight(.semibold))
                                                Text(student.status).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(SchoologyGradeValueFormatter.display(student.grade)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                                        }
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
                                        if !revision.body.isEmpty { Text(revision.body).textSelection(.enabled) }
                                        ForEach(revision.attachments) { attachment in Link(destination: attachment.url) { Label(attachment.title, systemImage: "paperclip") } }
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
        .toolbar {
            if !context.isTeacher {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Create submission", systemImage: "plus") {
                        Button("Create Text Submission", systemImage: "square.and.pencil") {
                            showingTextComposer = true
                        }
                        Button("Upload Submission", systemImage: "arrow.up.doc") {
                            showingFileImporter = true
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await uploadSubmission(from: url) }
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
    }
    private func load() async {
        guard context.canSubmit else { return }
        loading = true
        error = nil
        do { summary = try await session.loadAssignmentSubmissions(sectionID: sectionID, context: context) }
        catch { self.error = error.localizedDescription }
        loading = false
    }

    private func uploadSubmission(from url: URL) async {
        guard !isUploading else { return }
        isUploading = true
        defer { isUploading = false }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            try await session.submitAssignmentFile(
                data: data,
                filename: url.lastPathComponent,
                mime: mime,
                sectionID: sectionID,
                assignmentID: context.assignment.id
            )
            await load()
        } catch {
            uploadError = error.localizedDescription
        }
    }
}
