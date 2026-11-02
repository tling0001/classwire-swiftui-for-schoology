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

struct SchoologyCourse: Identifiable, Sendable {
    let id: String
    let title: String
    let courseCode: String
    let section: String

    static func decodeList(_ value: Any?) -> [SchoologyCourse] {
        guard let items = value as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let id = item["id"] else { return nil }
            return SchoologyCourse(
                id: String(describing: id),
                title: item["course_title"] as? String ?? item["title"] as? String ?? "Course",
                courseCode: item["course_code"] as? String ?? "",
                section: item["section_title"] as? String ?? ""
            )
        }
    }
}

struct SchoologyGroup: Identifiable, Sendable {
    let id: String
    let title: String

    static func decodeList(_ value: Any?) -> [SchoologyGroup] {
        guard let items = value as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let id = item["id"] else { return nil }
            return SchoologyGroup(id: String(describing: id), title: item["title"] as? String ?? "Group")
        }
    }
}

struct SchoologyActivity: Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let created: String

    static func decodeList(_ value: Any?) -> [SchoologyActivity] {
        guard let items = value as? [[String: Any]] else { return [] }
        return items.enumerated().map { index, item in
            SchoologyActivity(
                id: String(describing: item["id"] ?? index),
                title: item["title"] as? String ?? item["type"] as? String ?? "Schoology update",
                body: item["body"] as? String ?? item["message"] as? String ?? "",
                created: item["created"] as? String ?? ""
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
        id = String(describing: rawID)
        title = json["title"] as? String ?? json["name"] as? String ?? "School"
        domain = json["domain"] as? String ?? ""
    }
}
