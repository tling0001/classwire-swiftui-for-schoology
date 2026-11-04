struct SchoologyGradeAssignment: Identifiable, Sendable {
    let id: String
    let title: String
    let grade: String
    let maxPoints: String
    let due: String
    let comment: String
    let itemType: String
}

struct SchoologyGradeCategory: Identifiable, Sendable {
    let id: String
    let title: String
    let weight: String
    let assignments: [SchoologyGradeAssignment]
}

struct SchoologyGradePeriod: Identifiable, Sendable {
    let id: String
    let title: String
    let categories: [SchoologyGradeCategory]
}

struct SchoologyGradebook: Sendable {
    let courseID: String
    let overallGrade: String
    let overallComment: String
    let gradingScaleID: String
    let periods: [SchoologyGradePeriod]
}
