import Foundation

enum SchoologyLikeTarget: Hashable, Identifiable {
    case update(String)
    case comment(updateID: String, commentID: String)

    var id: String {
        switch self {
        case .update(let updateID):
            "update-\(updateID)"
        case .comment(let updateID, let commentID):
            "comment-\(updateID)-\(commentID)"
        }
    }
}
