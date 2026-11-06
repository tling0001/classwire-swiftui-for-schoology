import SwiftUI
struct SchoologyAssignmentDetailView: View {
    @Environment(AppSession.self) private var session
    @ScaledMetric(relativeTo: .body) private var richTextMinimumFontSize: CGFloat = 15.5
    let sectionID: String
    let assignmentID: String
    let title: String
    @State private var context: SchoologyAssignmentContext?
    @State private var selectedTab: SchoologyAssignmentTab = .info
    @State private var loading = true
    @State private var error: String?
    @State private var showingSubmissionTextComposer = false
    @State private var showingSubmissionUploadComposer = false
    @State private var submissionRefreshID = UUID()

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
                        let splitWidth = max(0, geometry.size.width - 1)
                        HStack(spacing: 0) {
                            assignmentTabs(context: context, includeSubmission: false)
                                .frame(width: splitWidth * (17.0 / 24.0)).frame(maxHeight: .infinity)
                            Divider()
                            submissionPane(context: context)
                                .frame(width: splitWidth * (7.0 / 24.0)).frame(maxHeight: .infinity)
                        }
                        .onAppear {
                            if selectedTab == .submissions { selectedTab = .info }
                        }
                    } else {
                        assignmentTabs(context: context, includeSubmission: context.canSubmit)
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
                        Button("Upload Submission", systemImage: "arrow.up.doc") { showingSubmissionUploadComposer = true }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSubmissionTextComposer) {
            if let context {
                SchoologyTextSubmissionComposerView(sectionID: sectionID, context: context) {
                    submissionRefreshID = UUID()
                    selectedTab = .submissions
                }
            }
        }
        .sheet(isPresented: $showingSubmissionUploadComposer) {
            if let context {
                SchoologyAssignmentSubmissionComposerView(
                    sectionID: sectionID,
                    assignmentID: context.assignment.id
                ) {
                    submissionRefreshID = UUID()
                    selectedTab = .submissions
                }
            }
        }
        .task(id: assignmentID) { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func assignmentTabs(context: SchoologyAssignmentContext, includeSubmission: Bool) -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            modernAssignmentTabs(context: context, includeSubmission: includeSubmission)
        } else {
            legacyAssignmentTabs(context: context, includeSubmission: includeSubmission)
        }
        #else
        modernAssignmentTabs(context: context, includeSubmission: includeSubmission)
        #endif
    }

    @available(macOS 15.0, *)
    private func modernAssignmentTabs(context: SchoologyAssignmentContext, includeSubmission: Bool) -> some View {
        TabView(selection: $selectedTab) {
            Tab("Info", systemImage: "info.circle", value: SchoologyAssignmentTab.info) {
                infoPane(context: context)
            }
            if context.allowComments {
                Tab("Comments", systemImage: "bubble.left", value: SchoologyAssignmentTab.comments) {
                    commentsPane
                }
            }
            if includeSubmission {
                Tab(context.isTeacher ? "Submissions" : "Submit", systemImage: "doc.text", value: SchoologyAssignmentTab.submissions) {
                    submissionPane(context: context)
                }
            }
        }
    }

    private func legacyAssignmentTabs(context: SchoologyAssignmentContext, includeSubmission: Bool) -> some View {
        TabView(selection: $selectedTab) {
            infoPane(context: context)
                .tabItem { Label("Info", systemImage: "info.circle") }
                .tag(SchoologyAssignmentTab.info)
            if context.allowComments {
                commentsPane
                    .tabItem { Label("Comments", systemImage: "bubble.left") }
                    .tag(SchoologyAssignmentTab.comments)
            }
            if includeSubmission {
                submissionPane(context: context)
                    .tabItem { Label(context.isTeacher ? "Submissions" : "Submit", systemImage: "doc.text") }
                    .tag(SchoologyAssignmentTab.submissions)
            }
        }
    }

    private func submissionPane(context: SchoologyAssignmentContext) -> some View {
        SchoologyAssignmentSubmissionView(
            sectionID: sectionID,
            context: context,
            refreshID: $submissionRefreshID
        )
    }

    private func infoPane(context: SchoologyAssignmentContext) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !context.attachments.isEmpty {
                    SchoologyAttachmentsDisclosure(attachments: context.attachments)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(context.assignment.title).font(.title2.bold())
                    if !context.assignment.subtitle.isEmpty {
                        Label(context.assignment.subtitle, systemImage: "calendar").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !context.maxPoints.isEmpty {
                        Label("\(SchoologyGradeValueFormatter.display(context.maxPoints)) points", systemImage: "chart.bar")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    SchoologyRichTextText(context.richDescription.isEmpty ? "No assignment description." : context.richDescription, minimumFontSize: richTextMinimumFontSize)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    if !context.teacherComment.isEmpty {
                        Divider()
                        Label("Teacher Comment", systemImage: "text.bubble").font(.headline)
                        SchoologyRichTextText(context.teacherComment, minimumFontSize: richTextMinimumFontSize).textSelection(.enabled)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding().frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
    }

    private var commentsPane: some View {
        SchoologyEntityCommentsView(
            title: "Comments",
            entityID: assignmentID,
            loadComments: { try await session.loadAssignmentComments(sectionID: sectionID, assignmentID: assignmentID) },
            submitComment: { body, parentID in
                try await session.postAssignmentComment(sectionID: sectionID, assignmentID: assignmentID, body: body, parentID: parentID)
            }
        )
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let loaded = try await session.loadAssignmentContext(sectionID: sectionID, assignmentID: assignmentID)
            context = loaded
            if !loaded.allowComments, selectedTab == .comments { selectedTab = .info }
            if !loaded.canSubmit && selectedTab == .submissions { selectedTab = .info }
        } catch { self.error = error.localizedDescription }
        loading = false
    }

}
