import SwiftUI

/// File materials open their action sheet directly from the Materials list instead of
/// pushing a placeholder destination page into the navigation stack.
struct SchoologyCourseMaterialLinkRow: View {
    @Environment(AppSession.self) private var session
    @Environment(\.openURL) private var openURL
    let courseID: String
    let item: SchoologyProfileItem
    @State private var selectedAttachment: SchoologyAttachment?
    @State private var isResolving = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        Button {
            Task { await openMaterial() }
        } label: {
            HStack(spacing: 10) {
                if isResolving {
                    ProgressView().frame(width: 20)
                } else {
                    Image(systemName: "link").foregroundStyle(.secondary).frame(width: 20).accessibilityHidden(true)
                }
                Text(item.title).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isResolving)
        .sheet(item: $selectedAttachment) { attachment in
            SchoologyAttachmentsView(attachments: [attachment])
        }
        .alert("Unable to open link", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Schoology did not provide a destination for this link.")
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
                openURL(url)
            } else {
                errorMessage = "Schoology did not provide a destination for this link."
                showingError = true
            }
        } catch {
            if let url = item.url ?? item.fileViewURL {
                openURL(url)
            } else {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

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
                    ProgressView().frame(width: 20)
                } else {
                    Image(systemName: "doc").foregroundStyle(.secondary).frame(width: 20).accessibilityHidden(true)
                }
                Text(item.title).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
