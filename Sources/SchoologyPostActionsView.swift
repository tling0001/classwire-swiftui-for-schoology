import SwiftUI

struct SchoologyPostActionsView: View {
    @Environment(AppSession.self) private var session
    let activity: SchoologyActivity
    @State private var likesCount: Int
    @State private var commentsCount: Int
    @State private var isLiked: Bool
    @State private var isUpdatingLike = false
    @State private var errorMessage: String?
    @State private var presentedSheet: PresentedSheet?
    @State private var recentComments: [SchoologyComment] = []
    @State private var recentCommentTotal = 0
    @State private var isLoadingRecentComments = false

    private enum PresentedSheet: String, Identifiable {
        case comments, likes
        var id: String { rawValue }
    }

    init(activity: SchoologyActivity) {
        self.activity = activity
        _likesCount = State(initialValue: activity.likes)
        _commentsCount = State(initialValue: activity.comments)
        _isLiked = State(initialValue: activity.isLiked)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 18) {
                Button("Comment", systemImage: "bubble.right") {
                    presentedSheet = .comments
                }
                .disabled(!canComment)

                if commentsCount > 0 {
                    Button {
                        presentedSheet = .comments
                    } label: {
                        Label("\(commentsCount)", systemImage: "bubble.right")
                    }
                    .disabled(!canComment)
                }

                Button(isLiked ? "Unlike" : "Like", systemImage: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup") {
                    toggleLike()
                }
                .disabled(isUpdatingLike)

                if likesCount > 0 {
                    Button {
                        presentedSheet = .likes
                    } label: {
                        Label("\(likesCount)", systemImage: "hand.thumbsup")
                    }
                }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(isLiked ? AnyShapeStyle(SchoologyStyle.blue) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .schoologyGlassSurface()
            .frame(maxWidth: .infinity, alignment: .leading)

            if !recentComments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recentComments) { comment in
                        SchoologyCommentRow(
                            comment: comment,
                            updateID: activity.id,
                            onReply: { _ in presentedSheet = .comments },
                            onOpenProfile: { userID in session.showPersonProfile(userID: userID) }
                        )
                    }
                    if recentCommentTotal > 2 {
                        Button("View more comments", systemImage: "ellipsis") {
                            presentedSheet = .comments
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(SchoologyStyle.blue)
                        .padding(.leading, 8)
                    }
                }
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if isLoadingRecentComments && commentsCount > 0 {
                ProgressView("Loading comments…")
                    .controlSize(.small)
                    .padding(.leading, 14)
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .task(id: activity.id) { await loadRecentComments() }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .comments:
                    SchoologyCommentsView(
                        realm: activity.commentRealm ?? "sections",
                        realmID: activity.commentRealmID ?? "",
                        updateID: activity.id,
                        onCommentPosted: {
                            commentsCount += 1
                            Task { await loadRecentComments() }
                        }
                    )
                case .likes:
                    SchoologyLikesView(target: .update(activity.id)) { userID in
                        session.showPersonProfile(userID: userID)
                    }
                    .schoologyFittedSheet()
                }
            }
            #if os(macOS)
            .frame(minWidth: 400, idealWidth: 520)
            #else
            .presentationDetents(presentedSheet?.id == "likes" ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    private var canComment: Bool {
        guard let realm = activity.commentRealm, let realmID = activity.commentRealmID else { return false }
        return ["sections", "groups", "schools", "users"].contains(realm) && !realmID.isEmpty
    }

    private func loadRecentComments() async {
        guard commentsCount > 0, canComment,
              let realm = activity.commentRealm, let realmID = activity.commentRealmID else {
            recentComments = []
            recentCommentTotal = 0
            return
        }
        isLoadingRecentComments = true
        defer { isLoadingRecentComments = false }
        do {
            let all = try await session.loadUpdateComments(realm: realm, realmID: realmID, updateID: activity.id)
            let ordered = SchoologyComment.ordered(all)
            recentCommentTotal = ordered.count
            recentComments = Array(ordered.suffix(2))
        } catch {
            recentComments = []
            recentCommentTotal = 0
        }
    }

    private func toggleLike() {
        guard !isUpdatingLike else { return }
        let previous = isLiked
        isLiked.toggle()
        likesCount = max(0, likesCount + (isLiked ? 1 : -1))
        isUpdatingLike = true
        errorMessage = nil
        Task {
            do {
                isLiked = try await session.setUpdateLike(updateID: activity.id, liked: isLiked)
            } catch {
                isLiked = previous
                likesCount = max(0, likesCount + (previous ? 1 : -1))
                errorMessage = error.localizedDescription
            }
            isUpdatingLike = false
        }
    }
}
