import SwiftUI

enum SchoologyResourceBrowserSource: Sendable {
    case course(courseID: String)
    case collection(collectionID: String)
    case group(groupID: String)
    case school(schoolID: String)
}

struct SchoologyResourcesContentView: View {
    let items: [SchoologyProfileItem]
    let source: SchoologyResourceBrowserSource
    let isLoading: Bool
    let error: String?
    let emptyTitle: String
    let emptyDescription: String
    var selection: Binding<[String: SchoologyPickedResource]>? = nil
    let onRefresh: () async -> Void

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                ProgressView("Loading resources…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, items.isEmpty {
                ContentUnavailableView("Unable to load resources", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if items.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: "folder", description: Text(emptyDescription))
            } else {
                List {
                    ForEach(items) { item in
                        SchoologyInlineResourceItemRow(item: item, source: source, selection: selection)
                    }
                }
                .schoologyInsetGroupedListStyle()
                .overlay(alignment: .top) {
                    if isLoading { ProgressView().padding(.top, 8) }
                }
            }
        }
        .refreshable { await onRefresh() }
    }
}

/// Shared recursive row for group resources, collections, the standalone Resources
/// page, and the resource picker. Its native folder disclosure rows mirror Course Materials.
struct SchoologyInlineResourceItemRow: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: SchoologyProfileItem
    let source: SchoologyResourceBrowserSource
    var selection: Binding<[String: SchoologyPickedResource]>? = nil
    @State private var isExpanded = false
    @State private var children: [SchoologyProfileItem]?
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        if item.isFolder {
            folderRow
        } else if let selection {
            selectableItemRow(selection)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } else if case .course(let courseID) = source {
            courseItemRow(courseID: courseID)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } else {
            resourceItemRow
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }

    private var folderRow: some View {
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
                    SchoologyInlineResourceItemRow(item: child, source: source, selection: selection)
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: isExpanded)
        .onChange(of: isExpanded) { _, expanded in
            guard expanded, children == nil, !isLoading else { return }
            Task { await loadChildren() }
        }
    }

    private func selectableItemRow(_ selection: Binding<[String: SchoologyPickedResource]>) -> some View {
        Button {
            var selected = selection.wrappedValue
            if selected[item.id] == nil {
                selected[item.id] = SchoologyPickedResource(id: item.id, title: item.title)
            } else {
                selected.removeValue(forKey: item.id)
            }
            selection.wrappedValue = selected
        } label: {
            HStack(spacing: 10) {
                Label(item.title, systemImage: resourceSymbol)
                    .foregroundStyle(.primary).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                if selection.wrappedValue[item.id] != nil {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint).accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selection.wrappedValue[item.id] == nil ? "Not selected" : "Selected")
    }

    @ViewBuilder
    private func courseItemRow(courseID: String) -> some View {
        if isLinkMaterial { SchoologyCourseMaterialLinkRow(courseID: courseID, item: item) }
        else if isFileMaterial { SchoologyCourseMaterialFileRow(courseID: courseID, item: item) }
        else {
            NavigationLink {
                SchoologyCourseMaterialDestinationView(courseID: courseID, item: item)
            } label: {
                Label(item.title, systemImage: resourceSymbol)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
        }
    }

    @ViewBuilder
    private var resourceItemRow: some View {
        if isLinkMaterial, let url = item.url ?? item.fileViewURL {
            Link(destination: url) {
                Label(item.title, systemImage: "link")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
        } else if let attachment {
            SchoologyAttachmentPreviewButton(attachment: attachment).frame(maxWidth: .infinity, alignment: .leading)
        } else if let url = item.url {
            NavigationLink {
                SchoologyEmbeddedWebView(url: url, title: item.title)
            } label: {
                Label(item.title, systemImage: resourceSymbol)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
        } else {
            NavigationLink {
                SchoologyProfileItemDetailSheet(item: item)
            } label: {
                Label(item.title, systemImage: resourceSymbol)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
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

    private var isLinkMaterial: Bool { item.documentType == "link" || item.kind.lowercased().contains("link") }

    private var isFileMaterial: Bool {
        let kind = item.kind.lowercased()
        if ["document", "file", "attachment", "file_attachment"].contains(kind) { return true }
        let ext = (item.url ?? item.fileViewURL)?.pathExtension.lowercased() ?? ""
        return ["pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "csv", "txt", "rtf",
                "jpg", "jpeg", "png", "gif", "heic", "webp"].contains(ext)
    }

    private var attachment: SchoologyAttachment? {
        guard let url = item.url ?? item.fileViewURL else { return nil }
        let kind = item.kind.lowercased()
        let isFile = item.fileViewURL != nil || !item.fileMIME.isEmpty ||
            kind.contains("file") || kind.contains("document") || !url.pathExtension.isEmpty
        guard isFile else { return nil }
        return SchoologyAttachment(
            title: item.fileName.isEmpty ? item.title : item.fileName,
            url: url,
            viewURL: item.fileViewURL == url ? nil : item.fileViewURL
        )
    }

    private var resourceSymbol: String {
        let kind = item.kind.lowercased()
        if isLinkMaterial { return "link" }
        if kind.contains("assignment") { return "pencil.circle.fill" }
        if kind.contains("page") { return "doc.text" }
        if kind.contains("assessment") || kind.contains("quiz") { return "checklist" }
        if kind.contains("discussion") { return "text.bubble" }
        if kind.contains("event") { return "calendar" }
        return "doc"
    }

    @MainActor
    private func loadChildren() async {
        guard !isLoading, children == nil else { return }
        isLoading = true
        loadError = nil
        do {
            let loaded: [SchoologyProfileItem]
            switch source {
            case .course(let courseID):
                loaded = try await session.loadCourseMaterials(courseID: courseID, folderID: item.id)
            case .collection(let collectionID):
                loaded = try await session.loadResourceItems(collectionID: collectionID, folderID: item.id)
            case .group(let groupID):
                loaded = try await session.loadGroupResources(groupID: groupID, folderID: item.id, collectionID: item.collectionID)
            case .school(let schoolID):
                loaded = try await session.loadSchoolResources(schoolID: schoolID, folderID: item.id, collectionID: item.collectionID)
            }
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
