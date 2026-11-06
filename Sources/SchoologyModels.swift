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
    var viewURL: URL? = nil
    var isLink: Bool = false
    var id: String { url.absoluteString }

    init(title: String, url: URL, viewURL: URL? = nil, isLink: Bool = false) {
        self.title = title
        self.url = url
        self.isLink = isLink
        let titleExtension = URL(fileURLWithPath: title).pathExtension.lowercased()
        let fileExtension = titleExtension.isEmpty ? url.pathExtension.lowercased() : titleExtension
        let mediaExtensions: Set<String> = [
            "mp4", "m4v", "mov", "webm", "avi", "mkv", "3gp", "wmv", "mpeg", "mpg",
            "mp3", "m4a", "aac", "wav", "aiff", "aif", "flac", "ogg", "oga", "opus", "wma", "caf"
        ]
        self.viewURL = mediaExtensions.contains(fileExtension) ? nil : viewURL
    }

    var fileExtension: String {
        let titleExtension = URL(fileURLWithPath: title).pathExtension.lowercased()
        return titleExtension.isEmpty ? url.pathExtension.lowercased() : titleExtension
    }

    var isVideo: Bool {
        ["mp4", "m4v", "mov", "webm", "avi", "mkv", "3gp", "wmv", "mpeg", "mpg"].contains(fileExtension)
    }

    var isAudio: Bool {
        ["mp3", "m4a", "aac", "wav", "aiff", "aif", "flac", "ogg", "oga", "opus", "wma", "caf"].contains(fileExtension)
    }

    var isPlayableMedia: Bool { isVideo || isAudio }

    static func isLinkRecord(_ item: [String: Any]) -> Bool {
        let linkFields = ["link_url", "linkURL", "linkUrl", "link_title", "linkTitle",
                          "href", "web_url", "webUrl", "launch_url", "launchUrl"]
        if linkFields.contains(where: { item[$0] != nil }) { return true }

        let fileFields = ["file_download_url", "fileDownloadURL", "download_path",
                          "downloadPath", "download_url", "downloadUrl", "filename", "fileName"]
        guard !fileFields.contains(where: { item[$0] != nil }),
              let rawURL = item["url"] as? String,
              let url = URL(string: rawURL) else { return false }
        return url.pathExtension.isEmpty
    }
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
    var schoolID: String? = nil
    var pictureURL: URL? = nil

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
    var commentRealm: String?
    var commentRealmID: String?
    let isLiked: Bool

    var createdDate: Date? { SchoologyValue.date(created) }

    static func decodeList(_ value: Any?) -> [SchoologyActivity] {
        SchoologyValue.list(value, keys: ["update", "updates", "update_list", "items", "data", "response"]).enumerated().map { index, item in
            let authorID = SchoologyValue.optionalString(item["user_id"] ?? item["uid"] ?? item["author_id"] ?? item["authorId"])
            let rawRealm = SchoologyValue.string(item["realm"] ?? item["realm_name"] ?? item["realmName"], fallback: "user").lowercased()
            let commentRealm: String
            switch rawRealm {
            case "section", "sections": commentRealm = "sections"
            case "group", "groups": commentRealm = "groups"
            case "school", "schools": commentRealm = "schools"
            case "user", "users": commentRealm = "users"
            default: commentRealm = rawRealm
            }
            let rawRealmID: Any?
            switch rawRealm {
            case "section", "sections":
                rawRealmID = item["section_id"] ?? item["sectionId"] ?? item["realm_id"] ?? item["realmId"]
            case "group", "groups":
                rawRealmID = item["group_id"] ?? item["groupId"] ?? item["realm_id"] ?? item["realmId"]
            case "school", "schools":
                rawRealmID = item["school_id"] ?? item["schoolId"] ?? item["realm_id"] ?? item["realmId"]
            default:
                rawRealmID = item["user_id"] ?? item["uid"] ?? item["realm_id"] ?? item["realmId"]
            }
            let commentRealmID = SchoologyValue.optionalString(rawRealmID)
            let likedValues: [Any?] = [item["user_like_action"], item["userLikeAction"], item["userLiked"], item["user_liked"], item["isLiked"], item["is_liked"], item["liked"]]
            let isLiked = likedValues.contains { SchoologyValue.bool($0) }
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
                let conversion = SchoologyValue.string(attachment["converted_status"] ?? attachment["convertedStatus"] ?? attachment["file_converted_status"] ?? attachment["fileConvertedStatus"]).lowercased()
                let converted = SchoologyValue.url(attachment["file_converted_download_url"] ?? attachment["fileConvertedDownloadURL"] ?? attachment["converted_download_path"] ?? attachment["convertedDownloadPath"])
                let viewURL = ["success", "converted", "1"].contains(conversion) ? converted : nil
                return SchoologyAttachment(title: title, url: url, viewURL: viewURL,
                    isLink: SchoologyAttachment.isLinkRecord(attachment))
            }
            return SchoologyActivity(
                id: SchoologyValue.string(item["id"] ?? item["update_id"] ?? item["updateId"], fallback: String(index)),
                authorName: SchoologyValue.string(item["display_name"] ?? item["author_name"] ?? item["user_name"]),
                authorID: authorID,
                avatarURL: SchoologyValue.url(avatar),
                body: rawBody,
                created: SchoologyValue.string(item["created"] ?? item["timestamp"] ?? item["created_at"] ?? item["createdAt"]),
                contextLabel: SchoologyValue.string(item["group_name"] ?? item["groupName"] ?? item["realm_title"] ?? item["realmTitle"]),
                attachments: attachments,
                imageURLs: imageURLs(in: rawBody, attachments: rawAttachments),
                likes: SchoologyValue.integer(item["likes"] ?? item["like_count"] ?? item["likeCount"]),
                comments: SchoologyValue.integer(item["num_comments"] ?? item["comment_count"] ?? item["commentCount"]),
                commentRealm: commentRealm,
                commentRealmID: commentRealmID,
                isLiked: isLiked
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
    let realm: String?
    let realmID: String?
    let sectionID: String?
    let groupID: String?
    let schoolID: String?
    let userID: String?
    let assignmentID: String?
    let discussionID: String?
    let externalToolID: String?
    let webURL: URL?

    var date: Date? { SchoologyValue.date(start) }

    var typeLabel: String {
        switch type.lowercased() {
        case "assignment": "Assignment"
        case "assessment", "assessment_v2", "managed_assessment", "quiz": "Test or Quiz"
        case "discussion": "Discussion"
        case "external_tool", "lti", "lti_assignment": "External Tool"
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
            guard let rawID = item["id"] ?? item["event_id"] ?? item["eventId"] else { return nil }
            let rawType = SchoologyValue.string(item["type"] ?? item["event_type"] ?? item["eventType"], fallback: "event").lowercased()
            let rawRealm = SchoologyValue.optionalString(item["realm"] ?? item["realm_name"] ?? item["realmName"])?.lowercased()
            let sectionID = SchoologyValue.optionalString(item["section_id"] ?? item["sectionId"] ?? (item["section"] as? [String: Any])?["id"])
            let groupID = SchoologyValue.optionalString(item["group_id"] ?? item["groupId"] ?? (item["group"] as? [String: Any])?["id"])
            let schoolID = SchoologyValue.optionalString(item["school_id"] ?? item["schoolId"] ?? (item["school"] as? [String: Any])?["id"])
            let userID = SchoologyValue.optionalString(item["user_id"] ?? item["userId"] ?? (item["user"] as? [String: Any])?["id"])
            let genericRealmID = SchoologyValue.optionalString(item["realm_id"] ?? item["realmId"])
            let realmID = genericRealmID ?? {
                guard let rawRealm else { return nil }
                switch rawRealm {
                case "section", "sections": return sectionID
                case "group", "groups": return groupID
                case "school", "schools": return schoolID
                case "user", "users": return userID
                default: return nil
                }
            }()
            let assignment = item["assignment_id"] ?? item["assignmentId"] ?? (item["assignment"] as? [String: Any])?["id"]
            let discussion = item["discussion_id"] ?? item["discussionId"] ?? (item["discussion"] as? [String: Any])?["discussion_id"] ?? (item["discussion"] as? [String: Any])?["discussionId"] ?? (item["discussion"] as? [String: Any])?["id"]
            let externalTool = item["external_tool_id"] ?? item["externalToolId"] ??
                (item["external_tool"] as? [String: Any])?["id"] ??
                (item["externalTool"] as? [String: Any])?["id"]
            return SchoologyUpcomingEvent(
                id: SchoologyValue.string(rawID),
                title: SchoologyValue.string(item["title"] ?? item["name"] ?? item["subject"], fallback: "Untitled"),
                type: rawType,
                start: SchoologyValue.string(item["start"] ?? item["start_date"] ?? item["startDate"] ?? item["start_time"] ?? item["startTime"] ?? item["date"] ?? item["due_date"] ?? item["dueDate"]),
                end: SchoologyValue.string(item["end"] ?? item["end_date"] ?? item["endDate"] ?? item["end_time"] ?? item["endTime"]),
                allDay: SchoologyValue.bool(item["all_day"] ?? item["allDay"]),
                realm: rawRealm,
                realmID: realmID,
                sectionID: sectionID,
                groupID: groupID,
                schoolID: schoolID,
                userID: userID,
                assignmentID: SchoologyValue.optionalString(assignment),
                discussionID: SchoologyValue.optionalString(discussion),
                externalToolID: SchoologyValue.optionalString(externalTool),
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

    static func postDateLabel(_ date: Date) -> String {
        let age = Date.now.timeIntervalSince(date)
        if age >= 0 && age < 24 * 60 * 60 {
            return date.formatted(.relative(presentation: .named))
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year().hour().minute())
    }

    /// Converts Schoology HTML to lightweight Markdown while retaining anchor destinations.
    /// Render the result with SchoologyRichTextText instead of a plain Text view.
    static func plainText(_ value: String) -> String {
        var result = value
        let anchorPattern = #"(?is)<a\b[^>]*?href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>"#
        if let regex = try? NSRegularExpression(pattern: anchorPattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            for match in regex.matches(in: result, range: range).reversed() {
                guard let full = Range(match.range, in: result),
                      let hrefRange = Range(match.range(at: 1), in: result),
                      let labelRange = Range(match.range(at: 2), in: result) else { continue }
                let href = String(result[hrefRange]).replacingOccurrences(of: "&amp;", with: "&")
                let label = String(result[labelRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&nbsp;|&#160;", with: " ", options: .regularExpression)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;|&apos;", with: "'")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                let safeLabel = label.replacingOccurrences(of: "[", with: "\\[")
                    .replacingOccurrences(of: "]", with: "\\]")
                result.replaceSubrange(full, with: "[\(safeLabel)](<\(href)>)")
            }
        }
        return result
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"</(?:p|div|li|h[1-6])\s*>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;|&#160;", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;|&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
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

    /// Schoology may repeat the containing thread ID for every individual message.
    /// Include author, timestamp, and a deterministic body digest for unique SwiftUI identity.
    var threadIdentity: String {
        var digest: UInt64 = 14_695_981_039_346_656_037
        for byte in body.utf8 {
            digest ^= UInt64(byte)
            digest &*= 1_099_511_628_211
        }
        return "\(id)|\(authorID ?? "")|\(created)|\(String(digest, radix: 16))"
    }

    static func decodeList(_ value: Any?) -> [SchoologyMessage] {
        let payload = (value as? [String: Any]).map { $0["data"] ?? $0["response"] ?? $0 } ?? value
        func threadRows(_ value: Any?) -> [[String: Any]] {
            if let rows = value as? [[String: Any]] { return rows }
            guard let object = value as? [String: Any] else { return [] }
            for key in ["message", "messages", "items", "data", "response"] {
                guard let nested = object[key] else { continue }
                if let rows = nested as? [[String: Any]], !rows.isEmpty { return rows }
                let rows = threadRows(nested)
                if !rows.isEmpty { return rows }
            }
            return object["id"] != nil || object["message_id"] != nil ? [object] : []
        }
        let rows = threadRows(payload)
        return rows.compactMap { item in
            guard // Android's Message model defines `id` as the individual message ID.
            // message_id can identify the containing conversation and is not unique
            // across every message in a thread.
            let rawID = item["id"] ?? item["message_id"] ?? item["messageId"] else { return nil }
            let attachmentRoot = item["attachments"] ?? item["attachment"] ?? [:]
            let attachmentItems = SchoologyValue.list(attachmentRoot, keys: ["files", "file", "links", "link", "embeds", "embed", "items"])
            let attachments = attachmentItems.compactMap { attachment -> SchoologyAttachment? in
                guard let url = SchoologyValue.url(
                    attachment["linkURL"] ?? attachment["linkUrl"] ?? attachment["href"] ??
                    attachment["url"] ?? attachment["file_download_url"] ?? attachment["download_path"]
                ) else { return nil }
                let conversion = SchoologyValue.string(attachment["converted_status"] ?? attachment["convertedStatus"] ?? attachment["file_converted_status"] ?? attachment["fileConvertedStatus"]).lowercased()
                let converted = SchoologyValue.url(attachment["file_converted_download_url"] ?? attachment["fileConvertedDownloadURL"] ?? attachment["converted_download_path"] ?? attachment["convertedDownloadPath"])
                let viewURL = ["success", "converted", "1"].contains(conversion) ? converted : nil
                return SchoologyAttachment(
                    title: SchoologyValue.string(attachment["title"] ?? attachment["filename"] ?? attachment["fileName"], fallback: url.lastPathComponent),
                    url: url, viewURL: viewURL,
                    isLink: SchoologyAttachment.isLinkRecord(attachment)
                )
            }
            let status = SchoologyValue.string(item["message_status"] ?? item["messageStatus"])
            let recipientList = SchoologyValue.string(item["recipient_ids"] ?? item["recipientIds"] ?? item["recipient_id"])
            let author = (item["author"] as? [String: Any]) ?? (item["sender"] as? [String: Any]) ?? [:]
            let authorUser = (author["user"] as? [String: Any]) ?? author
            let authorID = item["author_id"] ?? item["authorId"] ?? item["user_id"] ?? item["uid"] ??
                item["sender_id"] ?? item["senderId"] ?? author["id"] ?? author["user_id"]
            return SchoologyMessage(
                id: SchoologyValue.string(rawID),
                subject: SchoologyValue.string(item["subject"], fallback: "Message"),
                body: SchoologyValue.string(item["message"] ?? item["body"]),
                created: SchoologyValue.string(item["last_updated"] ?? item["lastUpdated"] ?? item["created"] ?? item["timestamp"]),
                status: status,
                isUnread: status.lowercased() == "unread" ||
                    (item["is_read"] as? Bool == false) ||
                    SchoologyValue.bool(item["unread"]) ||
                    (item["read"] as? Bool == false),
                authorID: SchoologyValue.optionalString(authorID),
                recipientID: SchoologyValue.optionalString(recipientList.split(separator: ",").first.map(String.init)),
                personName: SchoologyValue.string(authorUser["name_display"] ?? authorUser["display_name"] ?? authorUser["name"]),
                personPictureURL: SchoologyValue.url(authorUser["picture_url"] ?? authorUser["pictureUrl"] ?? authorUser["picture"]),
                attachments: attachments
            )
        }
    }

    static func == (lhs: SchoologyMessage, rhs: SchoologyMessage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SchoologyWebCookie: Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
}
