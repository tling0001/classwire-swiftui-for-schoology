import SwiftUI
struct SchoologyNotificationTargetView: View {
    @Environment(AppSession.self) private var session
    let notification: SchoologyNotification
    let argument: SchoologyNotificationArgument
    private var type: String { argument.type.lowercased() }
    private var targetID: String { argument.targetID ?? "" }
    private var realm: String { notification.realm }
    private var realmID: String { notification.realmID ?? "" }
    var body: some View {
        Group {
            if type == "assignment", !realmID.isEmpty {
                SchoologyAssignmentDetailView(sectionID: realmID, assignmentID: targetID, title: argument.title)
            } else if type == "discussion", ["sections", "groups", "schools"].contains(realm), !realmID.isEmpty {
                SchoologyDiscussionDetailView(realm: realm, realmID: realmID, itemID: targetID, title: argument.title)
            } else if type == "event", !realm.isEmpty, !realmID.isEmpty {
                SchoologyEventDetailView(realm: realm, realmID: realmID, eventID: targetID, title: argument.title)
            } else if type == "document", !realm.isEmpty, !realmID.isEmpty {
                SchoologyNotificationDocumentView(
                    realmID: realmID, documentID: targetID,
                    title: argument.title, documentType: argument.documentType,
                    fallbackURL: argument.url
                )
            } else if type == "user" {
                if notification.type == "badge_award", let currentUserID = session.auth?.userID {
                    SchoologyPersonProfileView(userID: currentUserID)
                } else {
                    SchoologyPersonProfileView(userID: targetID)
                }
            } else if type == "group" {
                GroupProfileView(group: session.groups.first(where: { $0.id == targetID }) ?? SchoologyGroup(id: targetID, title: argument.title))
            } else if type == "section" {
                SchoologyCourseProfileView(course: session.courses.first(where: { $0.id == targetID }) ?? SchoologyCourse(id: targetID, title: argument.title, courseCode: "", section: "", profileURL: nil, schoolID: nil))
            } else if type == "school" {
                SchoolProfileView(schoolID: targetID)
            } else if let url = argument.url ?? fallbackURL {
                SchoologyEmbeddedWebView(url: url, title: argument.title)
            } else {
                ContentUnavailableView("Unable to open notification item", systemImage: "exclamationmark.triangle",
                    description: Text("Schoology didn't provide a destination for this item."))
            }
        }
        .navigationTitle(argument.title)
    }
    private var fallbackURL: URL? {
        let host = session.canadianServer ? "app.schoologyca.com" : "app.schoology.com"
        let path: String
        switch type {
        case "assignment", "assessment", "assessment_v2", "managed_assessment": path = "/assignment/\(targetID)"
        case "discussion": path = "/discussion/\(targetID)"
        case "event": path = "/event/\(targetID)"
        case "document": path = "/\(realm)/\(realmID)/documents/\(targetID)"
        case "page": path = "/\(realm)/\(realmID)/pages/\(targetID)"
        case "media-album": path = "/\(realm)/\(realmID)/albums/\(targetID)"
        case "user": path = "/user/\(targetID)"
        case "group": path = "/group/\(targetID)"
        case "school": path = "/school/\(targetID)"
        case "section": path = "/course/\(targetID)"
        case "badge": path = "/user/\(session.user?.id ?? "")"
        default: return nil
        }
        return URL(string: "https://\(host)\(path)")
    }
}
