import Foundation

struct SchoologyComment: Identifiable, Sendable {
    let id: String
    let parentID: String?
    let authorID: String?
    var authorName: String
    var avatarURL: URL?
    let body: String
    let created: String
    let likes: Int
    let isLiked: Bool
    let isDeleted: Bool
    let attachments: [SchoologyAttachment]

    var createdDate: Date? { SchoologyValue.date(created) }

    static func decodeList(_ value: Any?) -> [SchoologyComment] {
        SchoologyValue.list(value, keys: ["comment", "comments", "items", "data", "response"]).enumerated().compactMap { index, item in
            guard let rawID = item["id"] ?? item["comment_id"] ?? item["commentId"] else { return nil }
            let person = (item["user"] as? [String: Any]) ??
                (item["author"] as? [String: Any]) ??
                (item["profile"] as? [String: Any]) ??
                (item["profile_info"] as? [String: Any]) ??
                (item["profileInfo"] as? [String: Any]) ??
                (item["creator"] as? [String: Any]) ??
                (item["created_by"] as? [String: Any]) ??
                (item["createdBy"] as? [String: Any]) ??
                (item["user_profile"] as? [String: Any]) ??
                (item["userProfile"] as? [String: Any]) ?? [:]
            let links = item["links"] as? [String: Any] ?? [:]
            let userLink = (links["user"] as? [String: Any])?["href"] ??
                (links["author"] as? [String: Any])?["href"] ??
                (links["creator"] as? [String: Any])?["href"]
            let linkedAuthorID = Self.userID(from: userLink)
            let authorID = SchoologyValue.optionalString(
                person["id"] ?? person["uid"] ?? person["user_id"] ?? person["userId"] ??
                item["user_id"] ?? item["userId"] ?? item["uid"] ??
                item["author_user_id"] ?? item["authorUserId"] ??
                item["creator_user_id"] ?? item["creatorUserId"] ??
                item["commenter_id"] ?? item["commenterId"] ??
                item["creater_id"] ?? item["creator_id"] ?? item["creatorId"] ??
                (item["created_by"] as? String) ?? (item["createdBy"] as? String) ??
                item["author_id"] ?? item["authorId"] ?? linkedAuthorID
            )
            let first = SchoologyValue.string(person["name_first"] ?? person["first_name"] ?? item["name_first"] ?? item["first_name"])
            let last = SchoologyValue.string(person["name_last"] ?? person["last_name"] ?? item["name_last"] ?? item["last_name"])
            let rawName = SchoologyValue.string(
                person["name_display"] ?? person["nameDisplay"] ?? person["display_name"] ??
                person["displayName"] ?? person["author_name"] ?? person["authorName"] ??
                person["user_name"] ?? person["userName"] ?? person["commenter_name"] ??
                person["commenterName"] ?? person["creator_name"] ?? person["creatorName"] ??
                person["name"] ?? item["name_display"] ?? item["nameDisplay"] ??
                item["display_name"] ?? item["displayName"] ?? item["author_name"] ??
                item["authorName"] ?? item["user_name"] ?? item["userName"] ?? item["username"]
            )
            let rawAuthorName = ["schoology", "schoology user"].contains(rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ? "" : rawName
            let authorName = rawAuthorName.isEmpty
                ? [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                : rawAuthorName
            let rawAttachments = item["attachments"] ?? item["attachment"] ?? item["files"]
            let attachments = SchoologyValue.list(
                rawAttachments,
                keys: ["files", "file", "links", "link", "attachment", "attachments", "items", "data"]
            ).compactMap { attachment -> SchoologyAttachment? in
                let rawURL = attachment["linkURL"] ?? attachment["linkUrl"] ?? attachment["href"] ??
                    attachment["url"] ?? attachment["web_url"] ?? attachment["webUrl"] ??
                    attachment["file_download_url"] ?? attachment["fileDownloadURL"] ??
                    attachment["download_path"] ?? attachment["downloadPath"]
                guard let url = SchoologyValue.url(rawURL) else { return nil }
                return SchoologyAttachment(
                    title: SchoologyValue.string(attachment["title"] ?? attachment["filename"] ?? attachment["fileName"], fallback: url.host ?? "Attachment"),
                    url: url
                )
            }
            let parent = SchoologyValue.optionalString(item["parent_id"] ?? item["parentId"])
            let parentID = parent == "0" ? nil : parent
            let liked = [item["user_like_action"], item["userLikeAction"], item["user_liked"], item["userLiked"], item["liked"], item["is_liked"], item["isLiked"]]
                .contains { SchoologyValue.bool($0) }
            return SchoologyComment(
                id: SchoologyValue.string(rawID, fallback: String(index)),
                parentID: parentID,
                authorID: authorID,
                authorName: authorName,
                avatarURL: SchoologyValue.url(
                    person["picture_url"] ?? person["pictureUrl"] ?? person["picture"] ??
                    person["avatar_url"] ?? person["avatarUrl"] ?? person["photo_url"] ??
                    person["photoUrl"] ?? person["photo"] ?? person["avatar"] ??
                    item["picture_url"] ?? item["pictureUrl"] ?? item["user_photo"] ??
                    item["avatar_url"] ?? item["avatarUrl"] ?? item["photo_url"] ?? item["photoUrl"]
                ),
                body: SchoologyValue.plainText(SchoologyValue.string(item["body"] ?? item["comment"] ?? item["message"])),
                created: SchoologyValue.string(item["created"] ?? item["timestamp"] ?? item["last_updated"] ?? item["lastUpdated"]),
                likes: SchoologyValue.integer(item["likes"] ?? item["like_count"] ?? item["likeCount"]),
                isLiked: liked,
                isDeleted: SchoologyValue.integer(item["status"] ?? 1) == 0,
                attachments: attachments
            )
        }
    }

    private static func userID(from value: Any?) -> String? {
        guard let href = value as? String, !href.isEmpty else { return nil }
        let pattern = #"/(?:users|user)/(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: href, range: NSRange(href.startIndex..., in: href)),
              let range = Range(match.range(at: 1), in: href) else { return nil }
        return String(href[range])
    }

    static func ordered(_ comments: [SchoologyComment]) -> [SchoologyComment] {
        let children = Dictionary(grouping: comments) { $0.parentID ?? "0" }
        var result: [SchoologyComment] = []
        var seen = Set<String>()
        func appendChildren(of parentID: String) {
            for comment in children[parentID] ?? [] where seen.insert(comment.id).inserted {
                result.append(comment)
                appendChildren(of: comment.id)
            }
        }
        appendChildren(of: "0")
        for comment in comments where seen.insert(comment.id).inserted {
            result.append(comment)
        }
        return result
    }
}
