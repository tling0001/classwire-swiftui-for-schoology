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
    var documentType: String = ""
    var folderColor: String = "blue"
    var isAvailable: Bool = true
    var hasCompletionRules: Bool = false
    var isCompleted: Bool? = nil
    var rawJSON: Data = Data()

    var isFolder: Bool { kind.lowercased() == "folder" || documentType.lowercased() == "folder" }

    static func decodeList(_ value: Any?, keys: [String]) -> [Self] {
        SchoologyValue.list(value, keys: keys).enumerated().compactMap { index, item in
            let nestedPerson = (item["user"] as? [String: Any]) ?? (item["member"] as? [String: Any]) ?? (item["profile"] as? [String: Any])
            let person = nestedPerson ?? item
            let rawKind = SchoologyValue.string(item["template_type"] ?? item["templateType"] ?? item["type"] ?? item["assignment_type"] ?? item["assignmentType"] ?? item["document_type"] ?? item["documentType"] ?? (item["template"] as? [String: Any])?["template_document_type"] ?? (item["template_fields"] as? [String: Any])?["document_type"]).lowercased()
            let templateFields = item["template_fields"] as? [String: Any] ?? item["templateFields"] as? [String: Any] ?? [:]
            let documentType = SchoologyValue.string(
                item["document_type"] ?? item["documentType"] ??
                item["template_document_type"] ?? item["templateDocumentType"] ??
                (item["template"] as? [String: Any])?["template_document_type"] ??
                templateFields["document_type"] ?? templateFields["documentType"] ??
                templateFields["template_document_type"] ?? templateFields["templateDocumentType"]
            ).lowercased()
            let normalizedKind = documentType == "folder" ? "folder" : rawKind
            let folderColor = SchoologyValue.string(
                item["color"] ?? item["folder_color"] ?? item["folderColor"] ??
                templateFields["color"] ?? templateFields["folder_color"] ?? templateFields["folderColor"],
                fallback: "blue"
            ).lowercased()
            let availabilityValue = item["available"] ?? item["is_available"] ?? item["isAvailable"]
            let isAvailable = availabilityValue == nil ? true : SchoologyValue.bool(availabilityValue)
            let completionRulesValue = item["has_rules"] ?? item["hasRules"] ?? item["has_completion_rules"] ?? item["hasCompletionRules"]
            let completionValue = item["completed"] ?? item["is_completed"] ?? item["isCompleted"]
            let hasCompletionRules = SchoologyValue.bool(completionRulesValue)
            let isCompleted = completionValue == nil ? nil : SchoologyValue.bool(completionValue)
            let rawID: Any?
            if nestedPerson != nil {
                rawID = person["id"] ?? person["uid"] ?? person["user_id"] ?? item["user_id"] ?? item["userId"] ?? item["uid"] ?? item["id"]
            } else if normalizedKind == "folder" {
                rawID = item["id"] ?? item["folder_id"] ?? item["folderId"]
            } else if rawKind.contains("discussion") {
                rawID = item["id"] ?? item["discussion_id"] ?? item["discussionId"] ??
                    item["template_id"] ?? item["templateID"] ?? item["templateId"]
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
            let attachmentValue = item["attachments"] ?? item["attachment"]
            let file = SchoologyValue.list(attachmentValue, keys: ["files", "file", "items"]).first ?? item
            let link = SchoologyValue.list(attachmentValue, keys: ["links", "link", "items"]).first ?? [:]
            let embed = SchoologyValue.list(attachmentValue, keys: ["embeds", "embed", "items"]).first ?? [:]
            let externalTool = SchoologyValue.list(attachmentValue, keys: ["external_tools", "external_tool", "tool", "items"]).first ?? [:]
            let video = SchoologyValue.list(attachmentValue, keys: ["videos", "video", "items"]).first ?? [:]
            let rawTitle = SchoologyValue.string(
                item["title"] ?? item["subject"] ?? item["template_title"] ?? item["templateTitle"] ??
                link["title"] ?? externalTool["title"] ?? video["title"] ??
                person["name_display"] ?? person["display_name"] ?? person["name"]
            )
            let fileViewURL = SchoologyValue.url(
                file["file_converted_download_url"] ?? file["fileConvertedDownloadURL"] ??
                file["converted_download_path"] ?? file["convertedDownloadPath"] ??
                item["file_converted_download_url"] ?? item["fileConvertedDownloadURL"] ??
                item["converted_download_path"] ?? item["convertedDownloadPath"]
            )
            let fileName = SchoologyValue.string(
                file["filename"] ?? file["fileName"] ?? file["title"] ??
                item["filename"] ?? item["fileName"], fallback: rawTitle
            )
            let fileMIME = SchoologyValue.string(
                file["filemime"] ?? file["fileMIME"] ?? file["mime"] ??
                item["filemime"] ?? item["fileMIME"]
            )
            let embedCode = SchoologyValue.string(embed["embed_code"] ?? embed["embedCode"])
            let embedSourceURL: URL? = {
                let pattern = #"(?is)\bsrc\s*=\s*["']([^"']+)["']"#
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: embedCode, range: NSRange(embedCode.startIndex..., in: embedCode)),
                      let range = Range(match.range(at: 1), in: embedCode) else { return nil }
                return SchoologyValue.url(String(embedCode[range]))
            }()
            let directResourceURLCandidate = SchoologyValue.url(
                person["profile_url"] ?? person["profileUrl"] ??
                item["url"] ?? item["web_url"] ?? item["webUrl"] ?? item["location"] ??
                (item["link"] as? String) ?? item["photo_url"] ?? item["photoUrl"] ?? item["original_url"] ?? item["originalUrl"]
            )
            let isResourceLink = documentType == "link" || normalizedKind.contains("link")
            let directResourceURL: URL? = {
                guard let candidate = directResourceURLCandidate else { return nil }
                guard isResourceLink, candidate.scheme == nil else { return candidate }
                return SchoologyValue.url("https://\(candidate.absoluteString)")
            }()
            let rawAttachmentLink = SchoologyValue.string(link["url"]).trimmingCharacters(in: .whitespacesAndNewlines)
            let attachmentLinkURL: URL? = {
                guard !rawAttachmentLink.isEmpty else { return nil }
                let lowercased = rawAttachmentLink.lowercased()
                let normalized = lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") ||
                    rawAttachmentLink.hasPrefix("/") || rawAttachmentLink.hasPrefix("//")
                    ? rawAttachmentLink : "https://\(rawAttachmentLink)"
                return SchoologyValue.url(normalized)
            }()
            let attachmentResourceURL = attachmentLinkURL ?? SchoologyValue.url(
                externalTool["url"] ?? video["url"] ??
                file["file_download_url"] ?? file["fileDownloadURL"] ??
                file["download_path"] ?? file["downloadPath"] ??
                item["file_download_url"] ?? item["download_path"]
            )
            let resourceURL = directResourceURL ?? attachmentResourceURL ?? embedSourceURL
            let school = (person["school"] as? [String: Any]) ?? [:]
            let rawDueDate = SchoologyValue.string(item["due"] ?? item["due_date"] ?? item["dueDate"])
            let subtitle = !roleText.isEmpty
                ? roleText
                : !rawDueDate.isEmpty
                    ? SchoologyValue.schoologyDateLabel(rawDueDate)
                    : SchoologyValue.string(item["created"] ?? item["timestamp"] ?? item["photo_count"])
            return Self(
                id: SchoologyValue.string(rawID, fallback: String(index)),
                title: rawTitle.isEmpty ? (displayName.isEmpty ? "ClassWire" : displayName) : rawTitle,
                body: SchoologyValue.plainText(SchoologyValue.string(
                    item["body"] ?? item["description"] ?? item["folder_description"] ?? item["folderDescription"] ??
                    item["resource_notes"] ?? item["resourceNotes"] ?? item["message"] ??
                    templateFields["body"] ?? link["summary"] ?? person["bio"] ?? person["about"]
                )),
                subtitle: subtitle,
                url: resourceURL,
                isAdmin: isAdmin,
                kind: normalizedKind,
                collectionID: SchoologyValue.optionalString(item["collection_id"] ?? item["collectionID"] ?? item["collectionId"]),
                firstName: firstName, lastName: lastName, preferredName: preferredName,
                pictureURL: SchoologyValue.url(person["picture_url"] ?? person["pictureUrl"] ?? person["picture"] ?? person["photo_url"] ?? person["photoUrl"]),
                role: roleText,
                email: SchoologyValue.string(person["primary_email"] ?? person["primaryEmail"] ?? person["email"]),
                username: SchoologyValue.string(person["username"] ?? person["user_name"] ?? person["userName"]),
                schoolName: SchoologyValue.string(person["school_name"] ?? person["schoolName"] ?? school["school_name"] ?? school["name"] ?? school["title"]),
                fileViewURL: fileViewURL,
                fileName: fileName,
                fileMIME: fileMIME,
                documentType: documentType,
                folderColor: folderColor,
                isAvailable: isAvailable,
                hasCompletionRules: hasCompletionRules,
                isCompleted: isCompleted,
                rawJSON: (try? JSONSerialization.data(withJSONObject: item, options: [.fragmentsAllowed])) ?? Data()
            )
        }
    }

    static func decodeDiscussionList(_ value: Any?) -> [Self] {
        let rows = SchoologyValue.list(value, keys: ["discussion", "discussions", "items", "data", "response"])
        let normalized = rows.map { row -> [String: Any] in
            var item = row
            let discussionID = row["id"] ?? row["discussion_id"] ?? row["discussionId"] ??
                row["template_id"] ?? row["templateID"] ?? row["templateId"]
            if let discussionID {
                item["id"] = discussionID
                item["discussion_id"] = discussionID
            }
            item["type"] = "discussion"
            item["template_type"] = "discussion"
            return item
        }
        return decodeList(["discussion": normalized], keys: ["discussion"])
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

