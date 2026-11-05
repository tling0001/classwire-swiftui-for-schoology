import Foundation
enum SchoologyAssignmentTab: String, CaseIterable, Identifiable, Hashable {
    case info = "Info"
    case comments = "Comments"
    case submissions = "Submissions"
    var id: String { rawValue }
}
struct SchoologyAssignmentContext: Sendable {
    let assignment: SchoologyProfileItem
    let canSubmit: Bool
    let allowComments: Bool
    let isTeacher: Bool
    let gradeItemID: String
    let enrollmentID: String?
    let ltiURL: URL?
    let currentGrade: String
    let maxPoints: String
    let richDescription: String
    let teacherComment: String
    let attachments: [SchoologyAttachment]
}
struct SchoologyAssignmentRevision: Identifiable, Sendable {
    let id: String
    let created: String
    let body: String
    let status: String
    let attachments: [SchoologyAttachment]
}
struct SchoologyAssignmentStudent: Identifiable, Sendable {
    let id: String
    let enrollmentID: String
    let name: String
    let status: String
    let grade: String
}
struct SchoologyAssignmentSubmissionSummary: Sendable {
    let grade: String
    let teacherComment: String
    let revisions: [SchoologyAssignmentRevision]
    let students: [SchoologyAssignmentStudent]
}

struct SchoologyTeacherGrade: Sendable {
    let grade: String
    let comment: String
    let commentVisible: Bool
}
