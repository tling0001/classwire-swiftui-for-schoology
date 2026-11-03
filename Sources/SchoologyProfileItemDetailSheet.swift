import SwiftUI

struct SchoologyProfileItemDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: SchoologyProfileItem

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(item.title).font(.title2.weight(.semibold))
                    if !item.subtitle.isEmpty { Text(item.subtitle).font(.subheadline).foregroundStyle(.secondary) }
                    if !item.body.isEmpty { Text(item.body).textSelection(.enabled) }
                    if let url = item.url {
                        Link(destination: url) {
                            Label("Open in Schoology", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            .navigationTitle("Details")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
