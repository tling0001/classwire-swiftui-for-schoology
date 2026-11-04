import SwiftUI

struct SchoologyGradeAssignmentRow: View {
    let assignment: SchoologyGradeAssignment

    private var score: String {
        assignment.maxPoints.isEmpty || assignment.grade == "—"
            ? SchoologyGradeValueFormatter.display(assignment.grade)
            : "\(SchoologyGradeValueFormatter.display(assignment.grade)) / \(SchoologyGradeValueFormatter.display(assignment.maxPoints))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(assignment.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text(score)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            if !assignment.due.isEmpty {
                Text("Due " + assignment.due)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !assignment.comment.isEmpty {
                Label(assignment.comment, systemImage: "text.bubble")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}
