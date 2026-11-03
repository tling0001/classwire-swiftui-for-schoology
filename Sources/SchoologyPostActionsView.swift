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
                Spacer()
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(isLiked ? AnyShapeStyle(SchoologyStyle.blue) : AnyShapeStyle(.secondary))

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .comments:
                    SchoologyCommentsView(
                        realm: activity.commentRealm ?? "sections",
                        realmID: activity.commentRealmID ?? "",
                        updateID: activity.id,
                        onCommentPosted: { commentsCount += 1 }
                    )
                case .likes:
                    SchoologyLikesView(target: .update(activity.id))
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var canComment: Bool {
        guard let realm = activity.commentRealm, let realmID = activity.commentRealmID else { return false }
        return ["sections", "groups", "schools", "users"].contains(realm) && !realmID.isEmpty
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
