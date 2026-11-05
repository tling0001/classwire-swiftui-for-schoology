import SwiftUI

/// A recursive, lazy-loading Materials row. Folders expand in place so navigating
/// a course never replaces the Materials list with a folder-only screen.
struct SchoologyInlineCourseMaterialRow: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    .transition(.opacity)
                } else if let loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if let children, children.isEmpty {
                    Text("This folder is empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if let children {
                    ForEach(children) { child in
                        SchoologyInlineCourseMaterialRow(courseID: courseID, item: child)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            } label: {
                HStack(alignment: .center, spacing: 9) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.body)
                        if !item.body.isEmpty {
                            Text(item.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            #if os(macOS)
            .padding(.vertical, 4)
            #else
            .controlSize(.regular)
            #endif
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .onChange(of: isExpanded) { _, expanded in
                guard expanded, children == nil, !isLoading else { return }
                Task { await loadChildren() }
            }
        } else {
            NavigationLink {
                SchoologyCourseMaterialDestinationView(courseID: courseID, item: item)
            } label: {
                Label(item.title, systemImage: symbol)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            #if os(macOS)
            .padding(.vertical, 4)
            #else
            .controlSize(.regular)
            #endif
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }

    private var symbol: String {
        let kind = item.kind.lowercased()
        if kind.contains("discussion") { return "text.bubble" }
        if kind == "page" { return "doc.text" }
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
        do {
            let loaded = try await session.loadCourseMaterials(courseID: courseID, folderID: item.id)
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                children = loaded
                isLoading = false
            }
        } catch {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }
}
