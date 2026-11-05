import SwiftUI

enum SchoologyResourceBrowserSource: Sendable {
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
    let onRefresh: () async -> Void

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                ProgressView("Loading resources…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, items.isEmpty {
                ContentUnavailableView(
                    "Unable to load resources",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if items.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "folder",
                    description: Text(emptyDescription)
                )
            } else {
                List {
                    ForEach(items) { item in
                        SchoologyInlineResourceItemRow(item: item, source: source)
                    }
                }
                .schoologyInsetGroupedListStyle()
                .overlay(alignment: .top) {
                    if isLoading {
                        ProgressView().padding(.top, 8)
                    }
                }
            }
        }
        .refreshable { await onRefresh() }
    }
}

struct SchoologyInlineResourceItemRow: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: SchoologyProfileItem
    let source: SchoologyResourceBrowserSource

    @State private var isExpanded = false
    @State private var children: [SchoologyProfileItem]?
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
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
                            SchoologyInlineResourceItemRow(item: child, source: source)
                                .transition(.opacity.combined(with: .move(edge: .top)))
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
            } else if let attachment {
                SchoologyAttachmentPreviewButton(attachment: attachment)
            } else if let url = item.url {
                NavigationLink {
                    SchoologyEmbeddedWebView(url: url, title: item.title)
                } label: {
                    Label(item.title, systemImage: resourceSymbol)
                }
            } else {
                NavigationLink {
                    SchoologyProfileItemDetailSheet(item: item)
                } label: {
                    Label(item.title, systemImage: resourceSymbol)
                }
            }
        }
    }

    private var attachment: SchoologyAttachment? {
        guard let url = item.url ?? item.fileViewURL else { return nil }
        let kind = item.kind.lowercased()
        let hasFileExtension = !url.pathExtension.isEmpty
        let isFile = item.fileViewURL != nil || !item.fileMIME.isEmpty ||
            kind.contains("file") || kind.contains("document") || hasFileExtension
        guard isFile else { return nil }
        return SchoologyAttachment(
            title: item.fileName.isEmpty ? item.title : item.fileName,
            url: url,
            viewURL: item.fileViewURL == url ? nil : item.fileViewURL
        )
    }

    private var resourceSymbol: String {
        let kind = item.kind.lowercased()
        if kind.contains("link") || item.url?.host != nil { return "link" }
        if kind.contains("page") { return "doc.text" }
        if kind.contains("assessment") || kind.contains("quiz") { return "checklist" }
        if kind.contains("discussion") { return "text.bubble" }
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
            case .collection(let collectionID):
                loaded = try await session.loadResourceItems(collectionID: collectionID, folderID: item.id)
            case .group(let groupID):
                loaded = try await session.loadGroupResources(
                    groupID: groupID,
                    folderID: item.id,
                    collectionID: item.collectionID
                )
            case .school(let schoolID):
                loaded = try await session.loadSchoolResources(
                    schoolID: schoolID,
                    folderID: item.id,
                    collectionID: item.collectionID
                )
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
