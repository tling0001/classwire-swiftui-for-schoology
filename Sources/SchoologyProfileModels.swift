import Foundation

struct SchoologyProfileItem: Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let subtitle: String
    let url: URL?
    let isAdmin: Bool
    let kind: String
    let collectionID: String?

    static func decodeList(_ value: Any?, keys: [String]) -> [Self] {
        SchoologyValue.list(value, keys: keys).enumerated().compactMap { index, item in
            let person = (item["user"] as? [String: Any]) ?? (item["member"] as? [String: Any]) ?? (item["profile"] as? [String: Any]) ?? item
            let rawID = person["id"] ?? person["uid"] ?? person["user_id"] ?? item["user_id"] ?? item["uid"] ?? item["id"]
            let nestedTemplate = item["template"] as? [String: Any] ?? [:]
            let nestedFields = item["template_fields"] as? [String: Any] ?? [:]
            return Self(
                id: SchoologyValue.string(rawID, fallback: String(index)),
                title: SchoologyValue.string(item["title"] ?? item["subject"] ?? item["template_title"] ?? item["templateTitle"] ?? person["name_display"] ?? person["display_name"] ?? person["name"], fallback: "Schoology"),
                body: SchoologyValue.plainText(SchoologyValue.string(item["body"] ?? item["description"] ?? item["message"])),
                subtitle: SchoologyValue.string(item["role_name"] ?? item["role"] ?? item["due"] ?? item["due_date"] ?? item["dueDate"] ?? item["created"] ?? item["timestamp"] ?? item["photo_count"]),
                url: SchoologyValue.url(item["link"] ?? item["url"] ?? item["web_url"] ?? item["webUrl"] ?? item["file_download_url"] ?? item["download_path"] ?? item["photo_url"] ?? item["photoUrl"] ?? item["original_url"] ?? item["originalUrl"] ?? ((item["attachments"] as? [String: Any])?["files"] as? [String: Any])?["file_download_url"] ?? ((item["attachment"] as? [String: Any])?["file"] as? [String: Any])?["file_download_url"]),
                isAdmin: SchoologyValue.bool(item["admin"] ?? item["is_admin"] ?? item["isAdmin"] ?? person["admin"] ?? person["is_admin"]),
                kind: SchoologyValue.string(item["template_type"] ?? item["templateType"] ?? item["type"] ?? item["assignment_type"] ?? item["assignmentType"] ?? item["document_type"] ?? item["documentType"] ?? nestedTemplate["template_document_type"] ?? nestedFields["document_type"]).lowercased(),
                collectionID: SchoologyValue.optionalString(item["collection_id"] ?? item["collectionID"] ?? item["collectionId"])
            )
        }
    }
}
struct SchoologyGroupPermissions: Sendable {
    let canPostUpdates: Bool
    let canCreateDiscussion: Bool
    let canCreateEvent: Bool
    let canCreateAlbum: Bool
    let canAddResources: Bool
    static func decode(_ json: [String: Any], groupID: String) -> Self {
        let rows = (json["response"] as? [[String: Any]]) ?? (json["responses"] as? [[String: Any]]) ?? []
        var bodies: [String: String] = [:]
        for row in rows {
            if let location = row["location"] as? String { bodies[location] = String(describing: row["body"] ?? "").lowercased() }
        }
        func allowed(_ tab: String) -> Bool { bodies["/v1/groups/\(groupID)/\(tab)"]?.range(of: #"\bpost\b"#, options: .regularExpression) != nil }
        return Self(canPostUpdates: allowed("updates"), canCreateDiscussion: allowed("discussions"), canCreateEvent: allowed("events"), canCreateAlbum: allowed("albums"), canAddResources: allowed("resources"))
    }
}
struct SchoologyGroupProfile: Sendable {
    let group: SchoologyGroup
    let permissions: SchoologyGroupPermissions
    let members: [SchoologyProfileItem]
    let updates: [SchoologyActivity]
    let upcoming: [SchoologyUpcomingEvent]
    let discussions: [SchoologyProfileItem]
    let albums: [SchoologyProfileItem]
    let resources: [SchoologyProfileItem]
}
struct SchoologyProfileSchool: Sendable { let id: String; let title: String; let pictureURL: URL?; let address: String; let phone: String }
struct SchoologySchoolProfile: Sendable { let school: SchoologyProfileSchool; let updates: [SchoologyProfileItem]; let upcoming: [SchoologyUpcomingEvent]; let resources: [SchoologyProfileItem] }
