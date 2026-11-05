import SwiftUI

struct SchoologyLikesView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let target: SchoologyLikeTarget
    let onSelect: (String) -> Void
    @State private var users: [SchoologyProfileItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading likes…")
                    .padding(36)
                    .frame(maxWidth: .infinity)
            } else if let errorMessage {
                ContentUnavailableView("Unable to load likes", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if users.isEmpty {
                ContentUnavailableView("No likes yet", systemImage: "hand.thumbsup")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(users) { user in
                            Button {
                                onSelect(user.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    if let pictureURL = user.pictureURL {
                                        AuthenticatedSchoologyImage(url: pictureURL)
                                            .frame(width: 36, height: 36)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 34))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(user.title)
                                        .font(.body.weight(.medium))
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 520)
            }
        }
        .navigationTitle("Likes")
        .task(id: target) { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            switch target {
            case .update(let updateID):
                users = try await session.loadUpdateLikes(updateID: updateID)
            case .comment(let updateID, let commentID):
                users = try await session.loadCommentLikes(updateID: updateID, commentID: commentID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
