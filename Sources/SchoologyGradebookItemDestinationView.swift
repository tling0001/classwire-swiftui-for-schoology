import SwiftUI

/// Reuses the same destination routing as Course Materials so gradebook rows
/// for discussions, assessments, events, pages, and assignments all open.
struct SchoologyGradebookItemDestinationView: View {
    let courseID: String
    let assignment: SchoologyGradeAssignment

    private var material: SchoologyProfileItem {
        let rawKind = assignment.itemType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let kind: String
        switch rawKind {
        case "0": kind = "assignment"
        case "1": kind = "discussion"
        case "test": kind = "assessment"
        default: kind = rawKind.isEmpty ? "assignment" : rawKind
        }
        return SchoologyProfileItem(
            id: assignment.id,
            title: assignment.title,
            body: "",
            subtitle: assignment.due,
            url: nil,
            isAdmin: false,
            kind: kind,
            collectionID: nil
        )
    }

    var body: some View {
        SchoologyCourseMaterialDestinationView(courseID: courseID, item: material)
    }
}
