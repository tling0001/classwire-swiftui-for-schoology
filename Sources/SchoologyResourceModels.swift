import Foundation

enum SchoologyResourceCategory: String, CaseIterable, Identifiable {
    case mine, shared, groups, apps
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mine: "My Resources"
        case .shared: "Shared"
        case .groups: "Groups"
        case .apps: "Resource Apps"
        }
    }
    var symbol: String {
        switch self {
        case .mine: "folder"
        case .shared: "person.2"
        case .groups: "person.3"
        case .apps: "square.grid.2x2"
        }
    }
}

struct SchoologyPickedResource: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
}

struct SchoologyResourceCollection: Identifiable, Sendable {
    let id: String
    let title: String
    let ownerID: String
    let realm: String
    let sharedCount: Int
    let typeID: String
    let folderID: String
    let category: SchoologyResourceCategory
    let imageURL: URL?

    func withCategory(_ category: SchoologyResourceCategory) -> Self {
        Self(id: id, title: title, ownerID: ownerID, realm: realm, sharedCount: sharedCount,
             typeID: typeID, folderID: folderID, category: category, imageURL: imageURL)
    }

    static func decodeList(_ value: Any?, keys: [String]) -> [Self] {
        SchoologyValue.list(value, keys: keys).compactMap { row in
            guard let rawID = row["collection_id"] ?? row["collectionID"] ?? row["id"] else { return nil }
            let id = SchoologyValue.string(rawID)
            guard !id.isEmpty else { return nil }
            return Self(
                id: id,
                title: SchoologyValue.string(row["collection_title"] ?? row["title"] ?? row["name"], fallback: "Resources"),
                ownerID: SchoologyValue.string(row["collection_owner_id"] ?? row["collectionOwnerId"] ?? row["uid"] ?? row["owner_id"]),
                realm: SchoologyValue.string(row["collection_realm"] ?? row["collectionRealm"] ?? row["realm"]).lowercased(),
                sharedCount: SchoologyValue.integer(row["shared_users_count"] ?? row["sharedUsersCount"] ?? row["shared_users"]),
                typeID: SchoologyValue.string(row["collection_type_id"] ?? row["collectionTypeId"]),
                folderID: SchoologyValue.string(row["folder_id"] ?? row["folderId"] ?? row["collection_folder_id"] ?? row["collectionFolderId"], fallback: "0"),
                category: .mine,
                imageURL: SchoologyValue.url(row["app_logo"] ?? row["appLogo"] ?? row["picture_url"] ?? row["pictureUrl"])
            )
        }
    }
}

struct SchoologyUserGradeCourse: Identifiable, Sendable {
    let id: String
    let title: String
    let courseTitle: String
    let overallGrade: String
    let imageURL: URL?

    static func decodeList(_ value: Any?) -> [Self] {
        SchoologyValue.list(value, keys: ["section", "sections", "grade", "grades", "items", "data", "response"]).compactMap { row in
            guard let rawID = row["section_id"] ?? row["sectionId"] ?? row["id"] else { return nil }
            let id = SchoologyValue.string(rawID)
            guard !id.isEmpty else { return nil }
            let rawFinal = row["final_grade"] ?? row["finalGrade"] ?? row["final_grades"] ?? row["finalGrades"]
            let final = (rawFinal as? [[String: Any]])?.first ?? (rawFinal as? [String: Any]) ?? [:]
            let periodValue = final["period"] ?? final["periods"] ?? final["final_period"] ?? final["finalPeriod"]
            let periods = SchoologyValue.list(periodValue, keys: ["period", "periods", "items"])
            let period = periods.first { SchoologyValue.string($0["period_id"] ?? $0["periodId"]) == "final" } ?? periods.first ?? final
            let overrideText = period["override_str"] ?? period["overrideStr"] ?? period["override_string"] ?? period["overrideString"] ??
                final["override_str"] ?? final["overrideStr"] ?? final["override_string"] ?? final["overrideString"]
            let numericOverride = period["override_numeric"] ?? period["overrideNumeric"] ??
                final["override_numeric"] ?? final["overrideNumeric"]
            let grade = overrideText ?? numericOverride ?? period["grade"] ?? final["grade"] ??
                final["calculated_grade"] ?? final["calculatedGrade"]
            let gradeText = grade == nil || grade is NSNull || SchoologyValue.string(grade).isEmpty
                ? "—" : SchoologyValue.string(grade)
            return Self(
                id: id,
                title: SchoologyValue.string(row["section_title"] ?? row["sectionTitle"] ?? row["course_title"] ?? row["courseTitle"], fallback: "Course"),
                courseTitle: SchoologyValue.string(row["course_title"] ?? row["courseTitle"] ?? row["section_title"] ?? row["sectionTitle"]),
                overallGrade: gradeText.hasSuffix("%") || gradeText == "—" || gradeText.contains(where: { $0.isLetter }) ? gradeText : gradeText + "%",
                imageURL: SchoologyValue.url(row["picture_url"] ?? row["pictureUrl"] ?? row["image_url"] ?? row["imageUrl"])
            )
        }
    }
}
