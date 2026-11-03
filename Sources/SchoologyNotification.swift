import Foundation
struct SchoologyNotification: Identifiable, Hashable, Sendable {
    let id: String
    let body: String
    let type: String
    let createdAt: Date?
    let realm: String
    let realmID: String?
    let isViewed: Bool
    let arguments: [SchoologyNotificationArgument]
    var title: String {
        switch type {
        case "grade_add": "Grade updated"
        case "badge_award": "Badge earned"
        case "course_materials_add": "New course material"
        case "grade_item_submit": "Assignment submitted"
        case "comment_private_add": "Private comment"
        case "discussion_add": "New discussion"
        case "comment_add": "New comment"
        default: "Schoology notification"
        }
    }
    var formattedBody: String {
        arguments.reduce(body) { text, argument in
            guard let range = text.range(of: "%s") else { return text }
            return text.replacingCharacters(in: range, with: argument.title)
        }
    }
    var symbol: String {
        switch type {
        case "grade_add": "chart.bar.fill"
        case "badge_award": "star.circle.fill"
        case "course_materials_add": "folder.badge.plus"
        case "grade_item_submit": "doc.text"
        case "comment_private_add": "lock.bubble"
        case "discussion_add": "text.bubble"
        case "comment_add": "bubble.left"
        default: "bell.badge"
        }
    }
    static func decodePage(_ value: Any?, start: Int, limit: Int) -> SchoologyNotificationPage {
        let root = value as? [String: Any] ?? [:]
        let payload = (root["data"] as? [String: Any]) ?? (root["response"] as? [String: Any]) ?? root
        let container = (payload["notifications"] as? [String: Any]) ?? (root["notifications"] as? [String: Any]) ?? payload
        let rawRows = container["notification"] ?? container["notifications"] ?? payload["notification"] ??
            payload["notifications"] ?? root["notification"] ?? root["notifications"] ?? container["items"]
        let rows = SchoologyValue.list(rawRows, keys: ["notification", "notifications", "items", "data"])
        let items = rows.enumerated().map { index, item in
            let rawRealm = SchoologyValue.string(item["realm"]).lowercased()
            let realm: String
            switch rawRealm {
            case "section": realm = "sections"
            case "group": realm = "groups"
            case "school": realm = "schools"
            case "user": realm = "users"
            default: realm = rawRealm
            }
            let args = SchoologyNotificationArgument.decodeList(item["body_args"] ?? item["bodyArgs"] ?? item["body_arg"])
            let created = (item["created"] ?? item["timestamp"]).map { SchoologyValue.string($0) } ?? ""
            let notificationID = SchoologyValue.string(item["id"] ?? item["notification_id"] ?? item["notificationId"], fallback: "notification-\(start + index)")
            return SchoologyNotification(
                id: notificationID,
                body: SchoologyValue.plainText(SchoologyValue.string(item["body"] ?? item["message"])),
                type: SchoologyValue.string(item["type"]).lowercased(),
                createdAt: SchoologyValue.date(created),
                realm: realm,
                // Android keeps the owning realm ID separate from the notification ID.
                realmID: SchoologyValue.optionalString(item["realm_id"] ?? item["realmId"]),
                isViewed: SchoologyValue.bool(item["viewed"]),
                arguments: args
            )
        }
        let count = SchoologyValue.integer(container["count"] ?? container["total"] ?? payload["count"])
        let unviewed = SchoologyValue.integer(container["unviewed_count"] ?? container["unviewedCount"] ?? payload["unviewed_count"] ?? payload["unviewedCount"])
        let links = (container["links"] as? [String: Any]) ?? (payload["links"] as? [String: Any]) ?? [:]
        let hasNext = SchoologyValue.optionalString(links["next"] ?? links["more"]) != nil
        let more = !items.isEmpty && (hasNext || count > start + items.count || items.count == limit)
        return SchoologyNotificationPage(notifications: items, count: count, unviewedCount: unviewed, hasMore: more)
    }
}
