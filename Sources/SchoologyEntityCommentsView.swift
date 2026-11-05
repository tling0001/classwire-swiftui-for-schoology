import SwiftUI

/// Shared native comment thread used by assignment comments and discussion replies.
struct SchoologyEntityCommentsView: View {
    @Environment(AppSession.self) private var session
    let title: String
    let entityID: String
    let loadComments: () async throws -> [SchoologyComment]
    let submitComment: (String, String?) async throws -> Void

    @State private var comments: [SchoologyComment] = []
    @State private var draft = ""
    @State private var replyingToID: String?
    @State private var replyingToName = ""
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var composerFocused: Bool

    var body: some View {
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
                            onOpenProfile: { userID in session.showPersonProfile(userID: userID) }
                        )
                    }
                }
            }
            .padding()
            .frame(maxWidth: 850)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) { composer }
        .task(id: entityID) { await load() }
        .refreshable { await load() }
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
                Button("Post", systemImage: "paperplane.fill") {
                    Task { await submit() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            comments = try await loadComments()
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
            try await submitComment(body, replyingToID)
            draft = ""
            replyingToID = nil
            replyingToName = ""
            composerFocused = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
