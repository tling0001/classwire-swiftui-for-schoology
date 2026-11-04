import SwiftUI
struct SchoologyAssignmentDetailView: View {
    @Environment(AppSession.self) private var session
    let sectionID: String
    let assignmentID: String
    let title: String
    @State private var context: SchoologyAssignmentContext?
    @State private var comments: [SchoologyProfileItem] = []
    @State private var selectedTab: SchoologyAssignmentTab = .info
    @State private var draft = ""
    @State private var loading = true
    @State private var error: String?
    @State private var isPosting = false
    @State private var showingSubmissionTextComposer = false
    @State private var showingSubmissionFileImporter = false
    @State private var showingSubmissionResourcePicker = false

    var body: some View {
        Group {
            if loading && context == nil {
                ProgressView("Loading assignment…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, context == nil {
                ContentUnavailableView("Unable to load assignment", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if let context, let ltiURL = context.ltiURL {
                SchoologyEmbeddedWebView(url: ltiURL, title: context.assignment.title)
            } else if let context {
                GeometryReader { geometry in
                    if geometry.size.width >= 801 && context.canSubmit {
                        HStack(spacing: 0) {
                            TabView(selection: $selectedTab) {
                                Tab("Info", systemImage: "info.circle", value: SchoologyAssignmentTab.info) {
                                    infoPane(context: context)
                                }
                                if context.allowComments {
                                    Tab("Comments", systemImage: "bubble.left", value: SchoologyAssignmentTab.comments) {
                                        commentsPane
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            Divider()
                            SchoologyAssignmentSubmissionView(sectionID: sectionID, context: context, showingTextComposer: $showingSubmissionTextComposer, showingFileImporter: $showingSubmissionFileImporter, showingResourcePicker: $showingSubmissionResourcePicker)
                                .frame(minWidth: 300, idealWidth: 390, maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .onAppear {
                            if selectedTab == .submissions { selectedTab = .info }
                        }
                    } else {
                        TabView(selection: $selectedTab) {
                            Tab("Info", systemImage: "info.circle", value: SchoologyAssignmentTab.info) {
                                infoPane(context: context)
                            }
                            if context.allowComments {
                                Tab("Comments", systemImage: "bubble.left", value: SchoologyAssignmentTab.comments) {
                                    commentsPane
                                }
                            }
                            if context.canSubmit {
                                Tab(context.isTeacher ? "Submissions" : "Submit", systemImage: "doc.text", value: SchoologyAssignmentTab.submissions) {
                                    SchoologyAssignmentSubmissionView(sectionID: sectionID, context: context, showingTextComposer: $showingSubmissionTextComposer, showingFileImporter: $showingSubmissionFileImporter, showingResourcePicker: $showingSubmissionResourcePicker)
                                }
                            }
                        }
                    }
                }
                .onChange(of: selectedTab) { _, next in
                    if next == .comments && !context.allowComments { selectedTab = .info }
                    if next == .submissions && !context.canSubmit { selectedTab = .info }
                }
            }
        }
        .navigationTitle(context?.assignment.title ?? title)
        .toolbar {
            if let context, context.canSubmit, !context.isTeacher {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Create submission", systemImage: "plus") {
                        Button("Create Text Submission", systemImage: "square.and.pencil") { showingSubmissionTextComposer = true }
                        Button("Upload Submission", systemImage: "arrow.up.doc") { showingSubmissionFileImporter = true }
                        Button("Submit Schoology Resource", systemImage: "folder") { showingSubmissionResourcePicker = true }
                    }
                }
            }
        }
        .task(id: assignmentID) { await load() }
        .refreshable { await load() }
    }

    private func infoPane(context: SchoologyAssignmentContext) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(context.assignment.title).font(.title2.bold())
                    if !context.assignment.subtitle.isEmpty {
                        Label(context.assignment.subtitle, systemImage: "calendar").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !context.maxPoints.isEmpty {
                        Label("\(SchoologyGradeValueFormatter.display(context.maxPoints)) points", systemImage: "chart.bar")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    SchoologyRichTextText(context.assignment.body.isEmpty ? "No assignment description." : context.assignment.body)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    if !context.teacherComment.isEmpty {
                        Divider()
                        Label("Teacher Comment", systemImage: "text.bubble").font(.headline)
                        SchoologyRichTextText(context.teacherComment).textSelection(.enabled)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 14))
                if !context.attachments.isEmpty {
                    SchoologyAttachmentsButton(attachments: context.attachments)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding().frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
    }

    private var commentsPane: some View {
        VStack(spacing: 0) {
            if let error {
                ContentUnavailableView("Unable to load comments", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if comments.isEmpty {
                ContentUnavailableView("No comments yet", systemImage: "bubble.left").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(comments) { comment in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(comment.title).font(.subheadline.bold())
                                SchoologyRichTextText(comment.body).textSelection(.enabled)
                                if !comment.subtitle.isEmpty { Text(comment.subtitle).font(.caption).foregroundStyle(.secondary) }
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding().frame(maxWidth: 900).frame(maxWidth: .infinity)
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Add a comment…", text: $draft, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
                Button("Post", systemImage: "paperplane.fill", action: postComment)
                    .disabled(isPosting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding().background(.bar)
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let loaded = try await session.loadAssignmentContext(sectionID: sectionID, assignmentID: assignmentID)
            context = loaded
            if loaded.allowComments {
                comments = try await session.loadAssignmentComments(sectionID: sectionID, assignmentID: assignmentID)
            } else {
                comments = []
                if selectedTab == .comments { selectedTab = .info }
            }
            if !loaded.canSubmit && selectedTab == .submissions { selectedTab = .info }
        } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func postComment() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let context, context.allowComments, !isPosting else { return }
        isPosting = true
        Task {
            do {
                try await session.postComment(realm: "sections", realmID: sectionID, entity: "assignments", entityID: assignmentID, body: value)
                draft = ""
                comments = try await session.loadAssignmentComments(sectionID: sectionID, assignmentID: assignmentID)
            } catch { self.error = error.localizedDescription }
            isPosting = false
        }
    }
}
