import SwiftUI

/// Dedicated Course Materials row restored from port.123. Course folders intentionally
/// do not use the generic Resources row: each DisclosureGroup remains a native List row,
/// and SwiftUI provides the original recursive indentation.
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
        if item.isFolder {
            DisclosureGroup(isExpanded: $isExpanded) {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
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
                        .foregroundStyle(folderTint)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.body)
                        if !item.body.isEmpty {
                            Text(item.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        SchoologyCourseMaterialStatusLabel(item: item)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .disabled(!item.isAvailable)
            .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: isExpanded)
            .onChange(of: isExpanded) { _, expanded in
                guard expanded, children == nil, !isLoading else { return }
                Task { await loadChildren() }
            }
        } else if isLinkMaterial {
            SchoologyCourseMaterialLinkRow(courseID: courseID, item: item)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } else if isFileMaterial {
            SchoologyCourseMaterialFileRow(courseID: courseID, item: item)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } else {
            NavigationLink {
                SchoologyCourseMaterialDestinationView(courseID: courseID, item: item)
            } label: {
                HStack(spacing: 10) {
                    Label(item.title, systemImage: symbol)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SchoologyCourseMaterialStatusLabel(item: item)
                }
                .contentShape(Rectangle())
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .disabled(!item.isAvailable)
        }
    }

    private var folderTint: Color {
        switch item.folderColor {
        case "black": .primary
        case "gray": .gray
        case "green": .green
        case "orange": .orange
        case "pink": .pink
        case "purple": .purple
        case "red": .red
        case "yellow": .yellow
        default: .blue
        }
    }

    private var isLinkMaterial: Bool {
        let kind = item.kind.lowercased()
        let documentType = item.documentType.lowercased()
        return documentType == "link" || documentType == "external_tool" || kind.contains("link")
    }

    private var isFileMaterial: Bool {
        let kind = item.kind.lowercased()
        let documentType = item.documentType.lowercased()
        if ["file", "attachment", "file_attachment"].contains(kind) || documentType == "file" { return true }
        let ext = (item.url ?? item.fileViewURL)?.pathExtension.lowercased() ?? ""
        return ["pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "csv", "txt", "rtf",
                "jpg", "jpeg", "png", "gif", "heic", "webp"].contains(ext)
    }

    private var symbol: String {
        let kind = item.kind.lowercased()
        if item.documentType.lowercased() == "external_tool" { return "app" }
        if isLinkMaterial { return "link" }
        if kind.contains("discussion") { return "text.bubble" }
        if kind.contains("page") { return "doc.text" }
        if kind.contains("assignment") { return "pencil" }
        if kind.contains("event") { return "calendar" }
        if ["assessment", "assessment_v2", "managed_assessment", "quiz"].contains(kind) { return "checklist" }
        if ["package", "scorm"].contains(kind) { return "shippingbox" }
        if ["web_package", "webpackage"].contains(kind) { return "globe" }
        if ["media-album", "album"].contains(kind) { return "photo.on.rectangle" }
        switch item.documentType.lowercased() {
        case "external_tool": return "app"
        case "video": return "play.rectangle"
        case "embed": return "rectangle.inset.filled"
        case "file": return "doc"
        default: return "doc"
        }
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


struct SchoologyCourseMaterialStatusLabel: View {
    let item: SchoologyProfileItem

    var body: some View {
        Group {
            if !item.isAvailable {
                Label("Unavailable", systemImage: "lock.fill").foregroundStyle(.secondary)
            } else if item.hasCompletionRules, let isCompleted = item.isCompleted {
                Label(isCompleted ? "Completed" : "Not completed",
                      systemImage: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? Color.green : Color.gray)
            }
        }
        .font(.caption)
        .fixedSize()
    }
}
