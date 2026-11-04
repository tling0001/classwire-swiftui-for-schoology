import SwiftUI

struct SchoologyGradebookView: View {
    let gradebook: SchoologyGradebook
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Overall Grade").font(.headline)
                    Spacer()
                    Text(gradebook.overallGrade).font(.headline.monospacedDigit())
                }
                if !gradebook.overallComment.isEmpty {
                    Label(gradebook.overallComment, systemImage: "text.bubble")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))

            ForEach(gradebook.periods) { period in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(period.categories) { category in
                            DisclosureGroup {
                                if category.assignments.isEmpty {
                                    ContentUnavailableView("No assignments", systemImage: "doc.text")
                                } else {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(category.assignments) { assignment in
                                            SchoologyGradeAssignmentRow(assignment: assignment)
                                            if assignment.id != category.assignments.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(category.title).font(.subheadline.weight(.semibold))
                                    Spacer(minLength: 8)
                                    if !category.weight.isEmpty {
                                        Text(category.weight + (category.weight.contains("%") ? "" : "%"))
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .tint(.primary)
                            .padding(.leading, 8)
                        }
                    }
                    .padding(.leading, 8)
                } label: {
                    Text(period.title)
                        .font(.headline)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .tint(.primary)
                .padding(12)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
            }

            if gradebook.periods.isEmpty {
                ContentUnavailableView("No grades available", systemImage: "chart.bar")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }

}
