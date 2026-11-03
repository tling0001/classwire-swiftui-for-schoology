import Foundation
struct SchoologyNotificationArgument: Identifiable, Hashable, Sendable {
    let id: String
    let targetID: String?
    let type: String
    let title: String
    let assignmentType: String?
    let documentType: String?
    let url: URL?
    let children: [SchoologyNotificationArgument]
    var canOpen: Bool { targetID != nil && type != "more" && !type.isEmpty }
    var symbol: String {
        switch type {
        case "assignment": "doc.text"
        case "assessment", "assessment_v2", "managed_assessment": "doc.text.magnifyingglass"
        case "discussion": "text.bubble"
        case "event": "calendar"
        case "document": "doc"
        case "page": "doc.richtext"
        case "user": "person"
        case "group": "person.3"
        case "school": "building.2"
        case "section": "book.closed"
        case "media-album": "photo.on.rectangle"
        default: "arrow.up.right.square"
        }
    }
    static func decodeList(_ value: Any?, prefix: String = "arg") -> [SchoologyNotificationArgument] {
        SchoologyValue.list(value, keys: ["body_arg", "bodyArgs", "argument", "arguments", "items"]).enumerated().map { index, item in
            let type = SchoologyValue.string(item["type"] ?? item["template_type"] ?? item["templateType"]).lowercased()
            let targetID = SchoologyValue.optionalString(item["id"] ?? item["object_id"] ?? item["objectId"])
            let children = decodeList(item["all"] ?? item["more"] ?? item["items"], prefix: "\(prefix)-\(index)")
            return SchoologyNotificationArgument(
                id: "\(prefix)-\(index)-\(targetID ?? type)", targetID: targetID, type: type,
                title: SchoologyValue.plainText(SchoologyValue.string(item["title"], fallback: "Schoology item")),
                assignmentType: SchoologyValue.optionalString(item["assignment_type"] ?? item["assignmentType"]),
                documentType: SchoologyValue.optionalString(item["document_type"] ?? item["documentType"]),
                url: SchoologyValue.url(item["url"] ?? item["href"] ?? item["web_url"] ?? item["webUrl"]),
                children: children
            )
        }
    }
}
