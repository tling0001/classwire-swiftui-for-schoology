import SwiftUI

/// A recursive, lazy-loading Materials row. Folders expand in place so navigating
/// a course never replaces the Materials list with a folder-only screen.
struct SchoologyInlineCourseMaterialRow: View {
    @Environment(AppSession.self) private var session
    let courseID: String
    let item: SchoologyProfileItem

    @State private var isExpanded = false
    @State private var children: [SchoologyProfileItem]?
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        if item.kind.lowercased() == "folder" {
            DisclosureGroup(isExpanded: $isExpanded) {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading folder…").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                } else if let loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else if let children, children.isEmpty {
                    Text("This folder is empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else if let children {
                    ForEach(children) { child in
                        SchoologyInlineCourseMaterialRow(courseID: courseID, item: child)
                    }
                }
            } label: {
                Label(item.title, systemImage: "folder")
                    .contentShape(Rectangle())
            }
            .onChange(of: isExpanded) { _, expanded in
                guard expanded, children == nil, !isLoading else { return }
                Task { await loadChildren() }
            }
        } else {
            NavigationLink {
                SchoologyCourseMaterialDestinationView(courseID: courseID, item: item)
            } label: {
                Label(item.title, systemImage: symbol)
            }
        }
    }

    private var symbol: String {
        let kind = item.kind.lowercased()
        if kind.contains("discussion") { return "text.bubble" }
        if kind.contains("assignment") { return "doc.text" }
        if kind.contains("event") { return "calendar" }
        if ["assessment", "assessment_v2", "managed_assessment", "quiz"].contains(kind) { return "checklist" }
        return "doc"
    }

    @MainActor
    private func loadChildren() async {
        guard !isLoading, children == nil else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            children = try await session.loadCourseMaterials(courseID: courseID, folderID: item.id)
        } catch {
            loadError = error.localizedDescription
        }
    }
}
