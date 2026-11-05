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
    var firstName: String = ""
    var lastName: String = ""
    var preferredName: String = ""
    var pictureURL: URL? = nil
    var role: String = ""
    var email: String = ""
    var username: String = ""
    var schoolName: String = ""
    var fileViewURL: URL? = nil
    var fileName: String = ""
    var fileMIME: String = ""

    static func decodeList(_ value: Any?, keys: [String]) -> [Self] {
        SchoologyValue.list(value, keys: keys).enumerated().compactMap { index, item in
            let nestedPerson = (item["user"] as? [String: Any]) ?? (item["member"] as? [String: Any]) ?? (item["profile"] as? [String: Any])
            let person = nestedPerson ?? item
            let rawKind = SchoologyValue.string(item["template_type"] ?? item["templateType"] ?? item["type"] ?? item["assignment_type"] ?? item["assignmentType"] ?? item["document_type"] ?? item["documentType"] ?? (item["template"] as? [String: Any])?["template_document_type"] ?? (item["template_fields"] as? [String: Any])?["document_type"]).lowercased()
            let rawID: Any?
            if nestedPerson != nil {
                rawID = person["id"] ?? person["uid"] ?? person["user_id"] ?? item["user_id"] ?? item["userId"] ?? item["uid"] ?? item["id"]
            } else if rawKind == "folder" {
                rawID = item["id"] ?? item["folder_id"] ?? item["folderId"]
            } else if !rawKind.isEmpty {
                rawID = item["template_id"] ?? item["templateID"] ?? item["templateId"] ?? item["assignment_id"] ?? item["assignmentId"] ?? item["discussion_id"] ?? item["discussionId"] ?? item["event_id"] ?? item["eventId"] ?? item["page_id"] ?? item["pageId"] ?? item["id"]
            } else {
                rawID = item["user_id"] ?? item["userId"] ?? item["uid"] ?? item["id"]
            }
            let firstName = SchoologyValue.string(person["name_display_start"] ?? person["nameDisplayStart"] ?? person["name_first"] ?? person["first_name"] ?? person["nameFirst"])
            let lastName = SchoologyValue.string(person["name_last"] ?? person["last_name"] ?? person["nameLast"])
            let preferredName = SchoologyValue.string(person["name_first_preferred"] ?? person["nameFirstPreferred"])
            let displayName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
            let roleValue = item["role"] ?? item["role_name"] ?? item["roleName"] ?? item["role_title"] ?? item["roleTitle"] ?? item["position"] ?? item["member_role"] ?? item["memberRole"] ?? person["role"] ?? person["role_name"] ?? person["roleName"] ?? person["role_title"] ?? person["roleTitle"] ?? person["position"] ?? person["member_role"] ?? person["memberRole"]
            let roleObject = roleValue as? [String: Any]
            let roleText = SchoologyValue.string(roleObject?["name"] ?? roleObject?["title"] ?? roleObject?["label"] ?? roleValue)
            let adminFlags: [Any?] = [item["admin"], item["is_admin"], item["isAdmin"], item["group_admin"], item["groupAdmin"], item["is_group_admin"], item["isGroupAdmin"], item["owner"], item["is_owner"], item["isOwner"], person["admin"], person["is_admin"], person["isAdmin"], person["group_admin"], person["groupAdmin"], person["is_group_admin"], person["isGroupAdmin"], person["owner"], person["is_owner"], person["isOwner"]]
            let normalizedRole = roleText.lowercased().replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
            let isAdmin = adminFlags.contains(where: { SchoologyValue.bool($0) }) || ["admin", "administrator", "owner"].contains { normalizedRole.contains($0) }
            let rawTitle = SchoologyValue.string(item["title"] ?? item["subject"] ?? item["template_title"] ?? item["templateTitle"] ?? person["name_display"] ?? person["display_name"] ?? person["name"])
            let file = SchoologyValue.list(item["attachments"] ?? item["attachment"], keys: ["files", "file", "items"]).first ?? item
            let fileViewURL = SchoologyValue.url(
                file["file_converted_download_url"] ?? file["fileConvertedDownloadURL"] ??
                file["converted_download_path"] ?? file["convertedDownloadPath"] ??
                item["file_converted_download_url"] ?? item["fileConvertedDownloadURL"] ??
                item["converted_download_path"] ?? item["convertedDownloadPath"]
            )
            let fileName = SchoologyValue.string(file["filename"] ?? file["fileName"] ?? item["filename"] ?? item["fileName"], fallback: rawTitle)
            let fileMIME = SchoologyValue.string(file["filemime"] ?? file["fileMIME"] ?? file["mime"] ?? item["filemime"] ?? item["fileMIME"])
            let school = (person["school"] as? [String: Any]) ?? [:]
            return Self(
                id: SchoologyValue.string(rawID, fallback: String(index)),
                title: rawTitle.isEmpty ? (displayName.isEmpty ? "Schoology" : displayName) : rawTitle,
                body: SchoologyValue.plainText(SchoologyValue.string(item["body"] ?? item["description"] ?? item["folder_description"] ?? item["folderDescription"] ?? item["message"] ?? person["bio"] ?? person["about"])),
                subtitle: SchoologyValue.string(roleText.isEmpty ? (item["due"] ?? item["due_date"] ?? item["dueDate"] ?? item["created"] ?? item["timestamp"] ?? item["photo_count"]) : roleText),
                url: SchoologyValue.url(person["profile_url"] ?? person["profileUrl"] ?? item["link"] ?? item["url"] ?? item["web_url"] ?? item["webUrl"] ?? file["file_download_url"] ?? file["fileDownloadURL"] ?? file["download_path"] ?? file["downloadPath"] ?? item["file_download_url"] ?? item["download_path"] ?? item["photo_url"] ?? item["photoUrl"] ?? item["original_url"] ?? item["originalUrl"]),
                isAdmin: isAdmin,
                kind: rawKind,
                collectionID: SchoologyValue.optionalString(item["collection_id"] ?? item["collectionID"] ?? item["collectionId"]),
                firstName: firstName, lastName: lastName, preferredName: preferredName,
                pictureURL: SchoologyValue.url(person["picture_url"] ?? person["pictureUrl"] ?? person["picture"] ?? person["photo_url"] ?? person["photoUrl"]),
                role: roleText,
                email: SchoologyValue.string(person["primary_email"] ?? person["primaryEmail"] ?? person["email"]),
                username: SchoologyValue.string(person["username"] ?? person["user_name"] ?? person["userName"]),
                schoolName: SchoologyValue.string(person["school_name"] ?? person["schoolName"] ?? school["school_name"] ?? school["name"] ?? school["title"]),
                fileViewURL: fileViewURL,
                fileName: fileName,
                fileMIME: fileMIME
            )
        }
    }
}
struct SchoologyUpdateDestination: Identifiable, Hashable, Sendable {
    let realm: String
    let resourceID: String
    let title: String
    var id: String { "\(realm):\(resourceID)" }
}

struct SchoologyHomeCreateDestination: Identifiable, Hashable, Sendable {
    let realm: String
    let resourceID: String
    let title: String
    let canCreateDiscussion: Bool
    let canCreateEvent: Bool
    var id: String { "\(realm):\(resourceID)" }
}

enum SchoologyHomeCreateAction: String, Identifiable {
    case discussion, event
    var id: String { rawValue }
    var title: String { self == .discussion ? "New Discussion" : "New Event" }
}

struct SchoologyCoursePermissions: Sendable {
    let canPostUpdates: Bool
    let canAddResources: Bool
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
    var members: [SchoologyProfileItem]
    var updates: [SchoologyActivity]
    var upcoming: [SchoologyUpcomingEvent]
    var discussions: [SchoologyProfileItem]
    var albums: [SchoologyProfileItem]
    var resources: [SchoologyProfileItem]
}
struct SchoologyProfileSchool: Sendable { let id: String; let title: String; let pictureURL: URL?; let address: String; let phone: String }
struct SchoologySchoolProfile: Sendable { let school: SchoologyProfileSchool; let updates: [SchoologyActivity]; let upcoming: [SchoologyUpcomingEvent]; let resources: [SchoologyProfileItem] }

