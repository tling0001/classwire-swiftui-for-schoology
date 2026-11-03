import Foundation

struct SchoologyAuth: Codable, Sendable {
    let token: String
    let secret: String
    let userID: String
}

struct SchoologyPendingSchoolLogin: Sendable {
    let credential: SchoologyAuth
    let authorizationURL: URL
}

struct SchoologyUser: Codable, Identifiable, Sendable {
    var id: String
    var nameDisplay: String
    var pictureURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case nameDisplay = "name_display"
        case pictureURL = "picture_url"
    }
}

enum HomeSection: String, CaseIterable, Identifiable {
    case recent = "Recent Activity"
    case dashboard = "Course Dashboard"
    case upcoming = "Upcoming"

    var id: String { rawValue }
}

struct SchoologyAttachment: Identifiable, Hashable, Sendable {
    let title: String
    let url: URL
    var id: String { url.absoluteString }
}

struct SchoologyCourse: Identifiable, Sendable {
    let id: String
    let title: String
    let courseCode: String
    let section: String
    let profileURL: URL?
    let schoolID: String?

    static func decodeList(_ value: Any?) -> [SchoologyCourse] {
        SchoologyValue.list(value, keys: ["section", "sections", "items", "data", "response"]).compactMap { item in
            guard let rawID = item["id"] ?? item["section_id"] ?? item["sectionId"] else { return nil }
            let image = item["profile_url"] ?? item["profileUrl"] ?? item["course_profile_url"] ??
                item["courseProfileUrl"] ?? item["course_theme"] ?? item["courseTheme"] ??
                item["image"] ?? item["course_image"] ?? item["courseImage"]
            return SchoologyCourse(
                id: SchoologyValue.string(rawID),
                title: SchoologyValue.string(item["course_title"] ?? item["courseTitle"] ?? item["title"] ?? item["section_title"], fallback: "Course"),
                courseCode: SchoologyValue.string(item["course_code"] ?? item["courseCode"]),
                section: SchoologyValue.string(item["section_title"] ?? item["sectionTitle"]),
                profileURL: SchoologyValue.url(image),
                schoolID: SchoologyValue.optionalString(item["school_id"] ?? item["schoolId"])
            )
        }
    }
}

struct SchoologyGroup: Identifiable, Sendable {
    let id: String
    let title: String

    static func decodeList(_ value: Any?) -> [SchoologyGroup] {
        SchoologyValue.list(value, keys: ["group", "groups", "items", "data", "response"]).compactMap { item in
            guard let rawID = item["id"] ?? item["group_id"] else { return nil }
            return SchoologyGroup(
                id: SchoologyValue.string(rawID),
                title: SchoologyValue.string(item["title"] ?? item["name"], fallback: "Group")
            )
        }
    }
}

struct SchoologyActivity: Identifiable, Sendable {
    let id: String
    var authorName: String
    let authorID: String?
    var avatarURL: URL?
    let body: String
    let created: String
    let contextLabel: String
    let attachments: [SchoologyAttachment]
    let imageURLs: [URL]
    let likes: Int
    let comments: Int

    var createdDate: Date? { SchoologyValue.date(created) }

    static func decodeList(_ value: Any?) -> [SchoologyActivity] {
        SchoologyValue.list(value, keys: ["update", "updates", "update_list", "items", "data", "response"]).enumerated().map { index, item in
            let authorID = SchoologyValue.optionalString(item["user_id"] ?? item["uid"] ?? item["author_id"] ?? item["authorId"])
            let avatar = item["user_photo"] ?? item["photo_url"] ?? item["picture_url"] ?? item["pictureUrl"]
            let rawBody = SchoologyValue.string(item["body"] ?? item["message"] ?? item["description"] ?? item["title"])
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
                let title = SchoologyValue.string(
                    attachment["title"] ?? attachment["filename"] ?? attachment["fileName"] ?? attachment["linkTitle"],
                    fallback: url.host ?? "Attachment"
                )
                return SchoologyAttachment(title: title, url: url)
            }
            return SchoologyActivity(
                id: SchoologyValue.string(item["id"] ?? item["update_id"] ?? item["updateId"], fallback: String(index)),
                authorName: SchoologyValue.string(item["display_name"] ?? item["author_name"] ?? item["user_name"]),
                authorID: authorID,
                avatarURL: SchoologyValue.url(avatar),
                body: SchoologyValue.plainText(rawBody),
                created: SchoologyValue.string(item["created"] ?? item["timestamp"] ?? item["created_at"] ?? item["createdAt"]),
                contextLabel: SchoologyValue.string(item["group_name"] ?? item["groupName"] ?? item["realm_title"] ?? item["realmTitle"]),
                attachments: attachments,
                imageURLs: imageURLs(in: rawBody, attachments: rawAttachments),
                likes: SchoologyValue.integer(item["likes"] ?? item["like_count"] ?? item["likeCount"]),
                comments: SchoologyValue.integer(item["num_comments"] ?? item["comment_count"] ?? item["commentCount"])
            )
        }
    }

    private static func imageURLs(in html: String, attachments: Any?) -> [URL] {
        var urls: [URL] = []
        let pattern = #"(?is)<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            for match in regex.matches(in: html, range: range) {
                guard let valueRange = Range(match.range(at: 1), in: html),
                      let url = SchoologyValue.url(String(html[valueRange])) else { continue }
                urls.append(url)
            }
        }

        let items = SchoologyValue.list(
            attachments,
            keys: ["files", "file", "links", "link", "attachment", "attachments", "items", "data"]
        )
        for item in items {
            let mime = SchoologyValue.string(item["filemime"] ?? item["fileMIME"] ?? item["mime"] ?? item["type"]).lowercased()
            let thumbnail = item["thumbnail"] ?? item["fileThumbnailURL"] ?? item["file_thumbnail_url"] ??
                item["image_url"] ?? item["imageUrl"]
            if let url = SchoologyValue.url(thumbnail) {
                urls.append(url)
            } else if mime.hasPrefix("image/") {
                let rawURL = item["file_download_url"] ?? item["fileDownloadURL"] ??
                    item["download_path"] ?? item["downloadPath"] ?? item["url"]
                if let url = SchoologyValue.url(rawURL) { urls.append(url) }
            }
        }

        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
}

struct SchoologyUpcomingEvent: Identifiable, Sendable {
    let id: String
    let title: String
    let type: String
    let start: String
    let end: String
    let allDay: Bool
    let sectionID: String?
    let assignmentID: String?
    let discussionID: String?
    let webURL: URL?

    var date: Date? { SchoologyValue.date(start) }

    var typeLabel: String {
        switch type.lowercased() {
        case "assignment": "Assignment"
        case "assessment", "assessment_v2", "managed_assessment", "quiz": "Test or Quiz"
        case "discussion": "Discussion"
        case "external_tool": "External Tool"
        case "event": "Event"
        default: "Upcoming"
        }
    }

    var timeLabel: String {
        guard !allDay, let date else { return allDay ? "All day" : "" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func decodeList(_ value: Any?) -> [SchoologyUpcomingEvent] {
        SchoologyValue.list(value, keys: ["event", "events", "items", "data", "response"]).compactMap { item in
            let rawType = SchoologyValue.string(item["type"]).lowercased()
            guard ["assignment", "assessment", "assessment_v2", "managed_assessment", "quiz", "discussion", "external_tool", "event"].contains(rawType),
                  let rawID = item["id"] ?? item["event_id"] ?? item["eventId"] else { return nil }
            let assignment = item["assignment_id"] ?? item["assignmentId"] ?? (item["assignment"] as? [String: Any])?["id"]
            let discussion = item["discussion_id"] ?? item["discussionId"] ?? (item["discussion"] as? [String: Any])?["id"]
            return SchoologyUpcomingEvent(
                id: SchoologyValue.string(rawID),
                title: SchoologyValue.string(item["title"], fallback: "Untitled"),
                type: rawType,
                start: SchoologyValue.string(item["start"] ?? item["start_date"] ?? item["startDate"]),
                end: SchoologyValue.string(item["end"] ?? item["end_date"] ?? item["endDate"]),
                allDay: SchoologyValue.bool(item["all_day"] ?? item["allDay"]),
                sectionID: SchoologyValue.optionalString(item["section_id"] ?? item["sectionId"]),
                assignmentID: SchoologyValue.optionalString(assignment),
                discussionID: SchoologyValue.optionalString(discussion),
                webURL: SchoologyValue.url(item["web_url"] ?? item["webUrl"] ?? item["url"])
            )
        }
    }
}

struct SchoologySchool: Identifiable, Sendable {
    let id: String
    let title: String
    let domain: String

    init?(json: [String: Any]) {
        guard let rawID = json["id"] else { return nil }
        id = SchoologyValue.string(rawID)
        title = SchoologyValue.string(json["title"] ?? json["name"], fallback: "School")
        domain = SchoologyValue.string(json["domain"])
    }
}

enum SchoologyValue {
    static func string(_ value: Any?, fallback: String = "") -> String {
        guard let value, !(value is NSNull) else { return fallback }
        return String(describing: value)
    }

    static func optionalString(_ value: Any?) -> String? {
        let value = string(value)
        return value.isEmpty ? nil : value
    }

    static func integer(_ value: Any?) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        return Int(string(value)) ?? 0
    }

    static func bool(_ value: Any?) -> Bool {
        if let number = value as? NSNumber { return number.boolValue }
        return ["1", "true", "yes"].contains(string(value).lowercased())
    }

    static func url(_ value: Any?) -> URL? {
        let raw = string(value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        if raw.hasPrefix("//") { return URL(string: "https:\(raw)") }
        if raw.hasPrefix("/") { return URL(string: "https://app.schoology.com\(raw)") }
        if raw.lowercased().hasPrefix("http://") {
            return URL(string: raw.replacingOccurrences(of: "http://", with: "https://", options: [.anchored, .caseInsensitive]))
        }
        return URL(string: raw)
    }

    static func list(_ value: Any?, keys: [String]) -> [[String: Any]] {
        if let items = value as? [[String: Any]] { return items }
        guard let object = value as? [String: Any] else { return [] }
        for key in keys {
            guard let nested = object[key] else { continue }
            let result = list(nested, keys: keys)
            if !result.isEmpty { return result }
        }
        if object["id"] != nil { return [object] }
        let entries = object.values.compactMap { $0 as? [String: Any] }
        return !entries.isEmpty && entries.allSatisfy { $0["id"] != nil } ? entries : []
    }

    static func date(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        if let seconds = Double(value), seconds > 0 {
            return Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1_000 : seconds)
        }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    static func plainText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</(?:p|div|li|h[1-6])\\s*>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;|&#160;", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;|&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SchoologyMessageFolder: String, CaseIterable, Identifiable {
    case inbox = "Inbox"
    case unread = "Unread"
    case sent = "Sent"
    var id: String { rawValue }
}

struct SchoologyMessage: Identifiable, Hashable, Sendable {
    let id: String
    var subject: String
    var body: String
    var created: String
    var status: String
    let isUnread: Bool
    var authorID: String?
    var recipientID: String?
    var personName: String
    var personPictureURL: URL?
    var attachments: [SchoologyAttachment]

    static func decodeList(_ value: Any?) -> [SchoologyMessage] {
        let payload = (value as? [String: Any]).map { $0["data"] ?? $0["response"] ?? $0 } ?? value
        let rows = SchoologyValue.list(payload, keys: ["message", "messages", "items", "data", "response"])
        return rows.compactMap { item in
            guard let rawID = item["id"] ?? item["message_id"] ?? item["messageId"] else { return nil }
            let attachmentRoot = item["attachments"] ?? item["attachment"] ?? [:]
            let attachmentItems = SchoologyValue.list(attachmentRoot, keys: ["files", "file", "links", "link", "embeds", "embed", "items"])
            let attachments = attachmentItems.compactMap { attachment -> SchoologyAttachment? in
                guard let url = SchoologyValue.url(
                    attachment["linkURL"] ?? attachment["linkUrl"] ?? attachment["href"] ??
                    attachment["url"] ?? attachment["file_download_url"] ?? attachment["download_path"]
                ) else { return nil }
                return SchoologyAttachment(
                    title: SchoologyValue.string(attachment["title"] ?? attachment["filename"] ?? attachment["fileName"], fallback: url.lastPathComponent),
                    url: url
                )
            }
            let status = SchoologyValue.string(item["message_status"] ?? item["messageStatus"])
            let recipientList = SchoologyValue.string(item["recipient_ids"] ?? item["recipientIds"] ?? item["recipient_id"])
            return SchoologyMessage(
                id: SchoologyValue.string(rawID),
                subject: SchoologyValue.string(item["subject"], fallback: "Message"),
                body: SchoologyValue.plainText(SchoologyValue.string(item["message"] ?? item["body"])),
                created: SchoologyValue.string(item["last_updated"] ?? item["lastUpdated"] ?? item["created"] ?? item["timestamp"]),
                status: status,
                isUnread: status.lowercased() == "unread" ||
                    (item["is_read"] as? Bool == false) ||
                    SchoologyValue.bool(item["unread"]) ||
                    (item["read"] as? Bool == false),
                authorID: SchoologyValue.optionalString(item["author_id"] ?? item["authorId"] ?? item["user_id"] ?? item["uid"] ?? (item["author"] as? [String: Any])?["id"]),
                recipientID: SchoologyValue.optionalString(recipientList.split(separator: ",").first.map(String.init)),
                personName: "",
                personPictureURL: nil,
                attachments: attachments
            )
        }
    }

    static func == (lhs: SchoologyMessage, rhs: SchoologyMessage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SchoologyNotification: Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let type: String
    let created: String
    let realm: String
    let realmID: String?

    static func decodeList(_ value: Any?) -> [SchoologyNotification] {
        let root = (value as? [String: Any])?["notifications"] ?? value
        let rows = SchoologyValue.list(root, keys: ["notification", "notifications", "items", "data", "response"])
        return rows.enumerated().map { index, item in
            let realm = SchoologyValue.string(item["realm"])
            let realmID = SchoologyValue.optionalString(item["realm_id"] ?? item["realmId"] ?? item["id"])
            return SchoologyNotification(
                id: SchoologyValue.string(item["id"] ?? item["notification_id"] ?? item["notificationId"], fallback: String(index)),
                title: SchoologyValue.string(item["title"] ?? item["type"], fallback: "Schoology notification"),
                body: SchoologyValue.plainText(SchoologyValue.string(item["body"] ?? item["message"] ?? item["body_args"])),
                type: SchoologyValue.string(item["type"]),
                created: SchoologyValue.string(item["created"] ?? item["timestamp"]),
                realm: realm,
                realmID: realmID
            )
        }
    }
}
