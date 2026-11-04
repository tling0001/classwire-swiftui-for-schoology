import SwiftUI

struct SchoologyCommentRow: View {
    @Environment(AppSession.self) private var session
    let comment: SchoologyComment
    let updateID: String
    let onReply: (String) -> Void
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var isUpdatingLike = false
    @State private var errorMessage: String?
    @State private var presentedLikes: SchoologyLikeTarget?

    init(comment: SchoologyComment, updateID: String, onReply: @escaping (String) -> Void) {
        self.comment = comment
        self.updateID = updateID
        self.onReply = onReply
        _isLiked = State(initialValue: comment.isLiked)
        _likeCount = State(initialValue: comment.likes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                if let avatarURL = comment.avatarURL {
                    AuthenticatedSchoologyImage(url: avatarURL)
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                }

                if let authorID = comment.authorID {
                    NavigationLink {
                        SchoologyPersonProfileView(userID: authorID)
                    } label: {
                        Text(comment.authorName.isEmpty ? "Schoology" : comment.authorName)
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(comment.authorName.isEmpty ? "Schoology" : comment.authorName)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                if let date = comment.createdDate {
                    Text(SchoologyValue.postDateLabel(date))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(comment.isDeleted ? "Comment deleted" : comment.body)
                .font(.body)
                .foregroundStyle(comment.isDeleted ? .secondary : .primary)
                .textSelection(.enabled)

            if !comment.isDeleted {
                ForEach(comment.attachments) { attachment in
                    Link(destination: attachment.url) {
                        Label(attachment.title, systemImage: "paperclip")
                            .font(.caption)
                    }
                }
            }

            HStack(spacing: 18) {
                if !comment.isDeleted {
                    Button("Reply", systemImage: "arrowshape.turn.up.left") {
                        onReply(comment.id)
                    }
                }
                Button(isLiked ? "Unlike" : "Like", systemImage: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup") {
                    toggleLike()
                }
                .disabled(isUpdatingLike)
                if likeCount > 0 {
                    Button {
                        presentedLikes = .comment(updateID: updateID, commentID: comment.id)
                    } label: {
                        Label("\(likeCount)", systemImage: "hand.thumbsup")
                    }
                }
                Spacer()
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(isLiked ? AnyShapeStyle(SchoologyStyle.blue) : AnyShapeStyle(.secondary))

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
        .padding(.leading, comment.parentID == nil ? 0 : 18)
        .sheet(item: $presentedLikes) { target in
            NavigationStack {
                SchoologyLikesView(target: target)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func toggleLike() {
        guard !isUpdatingLike else { return }
        let previous = isLiked
        isLiked.toggle()
        likeCount = max(0, likeCount + (isLiked ? 1 : -1))
        isUpdatingLike = true
        errorMessage = nil
        Task {
            do {
                isLiked = try await session.setCommentLike(updateID: updateID, commentID: comment.id, liked: isLiked)
            } catch {
                isLiked = previous
                likeCount = max(0, likeCount + (previous ? 1 : -1))
                errorMessage = error.localizedDescription
            }
            isUpdatingLike = false
        }
    }
}
