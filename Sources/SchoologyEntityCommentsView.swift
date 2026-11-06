import SwiftUI

/// Compatibility adapter that routes entity comment threads through the shared post-comments UI.
struct SchoologyEntityCommentsView: View {
    let title: String
    let entityID: String
    let loadComments: () async throws -> [SchoologyComment]
    let submitComment: (String, String?) async throws -> Void

    var body: some View {
        SchoologyCommentsView(
            title: title,
            entityID: entityID,
            loadComments: loadComments,
            submitComment: submitComment
        )
    }
}
