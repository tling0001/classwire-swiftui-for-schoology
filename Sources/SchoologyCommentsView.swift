import SwiftUI

/// The shared comments thread used by activity posts, assignments, discussions, and events.
struct SchoologyCommentsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    let title: String
    let entityID: String

    private let updateRealm: String?
    private let updateRealmID: String?
    private let loadCommentsAction: (() async throws -> [SchoologyComment])?
    private let submitCommentAction: ((String, String?) async throws -> Void)?
    private let onCommentPosted: () -> Void
    private let showsCloseButton: Bool

    @State private var comments: [SchoologyComment] = []
    @State private var draft = ""
    @State private var replyingToID: String?
    @State private var replyingToName = ""
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var composerFocused: Bool

    init(realm: String, realmID: String, updateID: String, onCommentPosted: @escaping () -> Void) {
        title = "Comments"
        entityID = updateID
        updateRealm = realm
        updateRealmID = realmID
        loadCommentsAction = nil
        submitCommentAction = nil
        self.onCommentPosted = onCommentPosted
        showsCloseButton = true
    }

    init(
        title: String,
        entityID: String,
        loadComments: @escaping () async throws -> [SchoologyComment],
        submitComment: @escaping (String, String?) async throws -> Void
    ) {
        self.title = title
        self.entityID = entityID
        updateRealm = nil
        updateRealmID = nil
        loadCommentsAction = loadComments
        submitCommentAction = submitComment
        onCommentPosted = {}
        showsCloseButton = false
    }

    var body: some View {
        Group {
            if showsCloseButton {
                commentsContent
                    .navigationTitle(title)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark") { dismiss() }
                        }
                    }
            } else {
                commentsContent
            }
        }
        .task(id: entityID) { await load() }
        .refreshable { await load() }
    }

    private var commentsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if isLoading && comments.isEmpty {
                    ProgressView("Loading comments…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                } else if let errorMessage, comments.isEmpty {
                    ContentUnavailableView("Unable to load comments", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if comments.isEmpty {
                    ContentUnavailableView("No comments yet", systemImage: "bubble.left")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                } else {
                    ForEach(SchoologyComment.ordered(comments)) { comment in
                        SchoologyCommentRow(
                            comment: comment,
                            updateID: entityID,
                            onReply: beginReply,
                            onOpenProfile: { userID in
                                if showsCloseButton { dismiss() }
                                session.showPersonProfile(userID: userID)
                            }
                        )
                    }
                }
            }
            .padding()
            .frame(maxWidth: 850)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) { composer }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            if replyingToID != nil {
                HStack {
                    Text("Replying to \(replyingToName.isEmpty ? "comment" : replyingToName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel reply") {
                        replyingToID = nil
                        replyingToName = ""
                    }
                    .font(.caption)
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Write a comment…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .onSubmit { Task { await submit() } }
                #if os(iOS)
                if composerFocused {
                    SchoologyKeyboardDoneToolbarButton { composerFocused = false }
                } else {
                    Button("Post", systemImage: "paperplane.fill") {
                        Task { await submit() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #else
                Button("Post", systemImage: "paperplane.fill") {
                    Task { await submit() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #endif
            }
        }
        .padding(12)
        .background(.regularMaterial)
    }

    private func beginReply(_ commentID: String) {
        replyingToID = commentID
        replyingToName = comments.first(where: { $0.id == commentID })?.authorName ?? ""
        composerFocused = true
    }

    private func load() async {
        if comments.isEmpty { isLoading = true }
        errorMessage = nil
        do {
            if let loadCommentsAction {
                comments = try await loadCommentsAction()
            } else if let updateRealm, let updateRealmID {
                comments = try await session.loadUpdateComments(realm: updateRealm, realmID: updateRealmID, updateID: entityID)
            } else {
                throw SchoologyAPIError.invalidResponse
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func submit() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            if let submitCommentAction {
                try await submitCommentAction(body, replyingToID)
            } else if let updateRealm, let updateRealmID {
                try await session.postUpdateComment(realm: updateRealm, realmID: updateRealmID, updateID: entityID, body: body, parentID: replyingToID)
            } else {
                throw SchoologyAPIError.invalidResponse
            }
            draft = ""
            replyingToID = nil
            replyingToName = ""
            composerFocused = false
            onCommentPosted()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
