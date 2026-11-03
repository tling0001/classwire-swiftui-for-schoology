import SwiftUI

struct SchoologyLikesView: View {
    @Environment(AppSession.self) private var session
    let target: SchoologyLikeTarget
    @State private var users: [SchoologyProfileItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading likes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView("Unable to load likes", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if users.isEmpty {
                ContentUnavailableView("No likes yet", systemImage: "hand.thumbsup")
            } else {
                List(users) { user in
                    NavigationLink {
                        SchoologyPersonProfileView(userID: user.id)
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
                        }
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.plain)
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
