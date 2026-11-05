import Foundation

enum SchoologyEventTab: String, CaseIterable, Identifiable, Hashable {
    case info = "Info"
    case comments = "Comments"

    var id: String { rawValue }
}

struct SchoologyEventContext: Sendable {
    let event: SchoologyProfileItem
    let richDescription: String
    let start: String
    let end: String
    let allDay: Bool
    let commentsEnabled: Bool
    let attachments: [SchoologyAttachment]
}
