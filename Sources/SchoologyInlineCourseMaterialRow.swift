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
        } else if isFileMaterial {
            SchoologyCourseMaterialFileRow(courseID: courseID, item: item)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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

    private var isFileMaterial: Bool {
        let kind = item.kind.lowercased()
        if ["document", "file", "attachment", "file_attachment"].contains(kind) { return true }
        let ext = (item.url ?? item.fileViewURL)?.pathExtension.lowercased() ?? ""
        return ["pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "csv", "txt", "rtf",
                "jpg", "jpeg", "png", "gif", "heic", "webp"].contains(ext)
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

/// File materials open their action sheet directly from the Materials list instead of
/// pushing a placeholder destination page into the navigation stack.
struct SchoologyCourseMaterialFileRow: View {
    @Environment(AppSession.self) private var session
    let courseID: String
    let item: SchoologyProfileItem

    @State private var selectedAttachment: SchoologyAttachment?
    @State private var linkedURL: URL?
    @State private var isShowingLinkedMaterial = false
    @State private var isResolving = false
    @State private var errorMessage: String?

    var body: some View {
        Button {
            Task { await openMaterial() }
        } label: {
            HStack(spacing: 10) {
                if isResolving {
                    ProgressView().controlSize(.small).frame(width: 20)
                } else {
                    Image(systemName: "doc").foregroundStyle(.secondary).frame(width: 20).accessibilityHidden(true)
                }
                Text(item.title).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isResolving)
        .sheet(item: $selectedAttachment) { attachment in
            SchoologyAttachmentsView(attachments: [attachment])
        }
        .navigationDestination(isPresented: $isShowingLinkedMaterial) {
            if let linkedURL {
                SchoologyEmbeddedWebView(url: linkedURL, title: item.title)
            } else {
                ContentUnavailableView("Unable to open material", systemImage: "exclamationmark.triangle")
            }
        }
        .alert("Unable to open material", item: $errorMessage) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
    }

    @MainActor
    private func openMaterial() async {
        guard !isResolving else { return }
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }
        do {
            let detail = try await session.loadCourseMaterialDetail(courseID: courseID, item: item)
            if let attachment = detail.attachment {
                selectedAttachment = attachment
            } else if let url = detail.linkURL ?? item.url ?? item.fileViewURL {
                if isSupportedFileURL(url) {
                    selectedAttachment = SchoologyAttachment(title: item.fileName.isEmpty ? item.title : item.fileName, url: url, viewURL: item.fileViewURL == url ? nil : item.fileViewURL)
                } else {
                    linkedURL = url
                    isShowingLinkedMaterial = true
                }
            } else {
                errorMessage = "Schoology did not return a file or link for this material."
            }
        } catch {
            if let url = item.url ?? item.fileViewURL {
                if isSupportedFileURL(url) {
                    selectedAttachment = SchoologyAttachment(title: item.fileName.isEmpty ? item.title : item.fileName, url: url, viewURL: item.fileViewURL == url ? nil : item.fileViewURL)
                } else {
                    linkedURL = url
                    isShowingLinkedMaterial = true
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func isSupportedFileURL(_ url: URL) -> Bool {
        let supported = ["pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "csv", "txt", "rtf",
                         "jpg", "jpeg", "png", "gif", "heic", "webp"]
        let urlExtension = url.pathExtension.lowercased()
        let filenameExtension = URL(fileURLWithPath: item.fileName).pathExtension.lowercased()
        return supported.contains(urlExtension) || supported.contains(filenameExtension)
    }
}
