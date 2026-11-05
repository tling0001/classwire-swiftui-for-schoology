import SwiftUI
import QuickLook
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

private struct SchoologyAttachmentDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SchoologyAttachmentPreviewButton: View {
    let attachment: SchoologyAttachment
    @State private var isPresented = false
    var body: some View {
        Button { isPresented = true } label: {
            Label(attachment.title, systemImage: "paperclip")
                .font(.subheadline).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens attachment actions")
        .sheet(isPresented: $isPresented) { SchoologyAttachmentsView(attachments: [attachment]) }
    }
}

struct SchoologyAttachmentsButton: View {
    let attachments: [SchoologyAttachment]
    @State private var isPresented = false
    var body: some View {
        Button { isPresented = true } label: {
            Label("View Attachments (\(attachments.count))", systemImage: "paperclip")
        }
        .sheet(isPresented: $isPresented) { SchoologyAttachmentsView(attachments: attachments) }
    }
}

struct SchoologyAttachmentsView: View {
    let attachments: [SchoologyAttachment]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(attachments) { attachment in SchoologyAttachmentActionRow(attachment: attachment) }
                .schoologyInsetGroupedListStyle()
                .navigationTitle("Attachments")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 440, idealWidth: 520)
        .frame(height: min(max(CGFloat(attachments.count) * 92 + 72, 180), 560))
        .schoologyFittedSheet()
        #else
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }
}

private struct SchoologyAttachmentActionRow: View {
    @Environment(AppSession.self) private var session
    let attachment: SchoologyAttachment
    @State private var previewURL: URL?
    @State private var isLoadingView = false
    @State private var isLoadingDownload = false
    @State private var isExportPresented = false
    @State private var exportDocument = SchoologyAttachmentDocument(data: Data())
    @State private var exportFilename = "Attachment"
    @State private var isSavingDownload = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(attachment.title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            HStack(spacing: 12) {
                Button {
                    Task { await loadForViewing() }
                } label: {
                    if isLoadingView {
                        ProgressView().frame(minWidth: 72, minHeight: 40)
                    } else {
                        Label("View", systemImage: "eye").frame(minWidth: 72, minHeight: 40)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingView || isLoadingDownload)

                Button {
                    beginDownload()
                } label: {
                    if isLoadingDownload {
                        ProgressView().frame(minWidth: 90, minHeight: 40)
                    } else {
                        Label("Download", systemImage: "arrow.down.to.line").frame(minWidth: 90, minHeight: 40)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingView || isLoadingDownload)
            }
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 5)
        .quickLookPreview($previewURL)
        #if os(iOS)
        .fileExporter(
            isPresented: $isExportPresented,
            document: exportDocument,
            contentTypes: [exportContentType],
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
        }
        #endif
        #if os(macOS)
        .sheet(isPresented: $isSavingDownload) {
            VStack(spacing: 12) {
                ProgressView()
                Text("Downloading and saving attachment…")
                    .font(.headline)
            }
            .padding(28)
            .frame(minWidth: 280, minHeight: 120)
        }
        #endif
    }

    private var icon: String {
        let ext = attachment.url.pathExtension.lowercased()
        if ["jpg","jpeg","png","gif","heic","webp"].contains(ext) { return "photo" }
        if ext == "pdf" { return "doc.richtext" }
        if ["doc","docx","rtf","txt"].contains(ext) { return "doc.text" }
        if ["ppt","pptx","key"].contains(ext) { return "rectangle.on.rectangle" }
        if ["xls","xlsx","csv","numbers"].contains(ext) { return "tablecells" }
        return "doc"
    }

    private var exportContentType: UTType {
        UTType(filenameExtension: attachment.url.pathExtension) ?? .data
    }

    private var safeFilename: String {
        var name = URL(fileURLWithPath: attachment.title).lastPathComponent
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        if name.isEmpty || name == "." { name = "Attachment" }
        if URL(fileURLWithPath: name).pathExtension.isEmpty,
           !attachment.url.pathExtension.isEmpty {
            name += "." + attachment.url.pathExtension
        }
        return name
    }

    @MainActor
    private func loadForViewing() async {
        guard !isLoadingView && !isLoadingDownload else { return }
        isLoadingView = true
        errorMessage = nil
        defer { isLoadingView = false }
        do {
            previewURL = try await session.downloadAttachment(attachment, forViewing: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func beginDownload() {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = safeFilename
        panel.allowedContentTypes = [exportContentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            Task { @MainActor in await downloadAndSave(to: destination) }
        }
        #else
        Task { await prepareExport() }
        #endif
    }

    #if os(iOS)
    @MainActor
    private func prepareExport() async {
        guard !isLoadingView && !isLoadingDownload else { return }
        isLoadingDownload = true
        errorMessage = nil
        defer { isLoadingDownload = false }
        do {
            let downloadedURL = try await session.downloadAttachment(attachment)
            exportDocument = SchoologyAttachmentDocument(data: try Data(contentsOf: downloadedURL))
            exportFilename = safeFilename
            isExportPresented = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    #if os(macOS)
    @MainActor
    private func downloadAndSave(to destination: URL) async {
        guard !isLoadingView && !isLoadingDownload else { return }
        isLoadingDownload = true
        isSavingDownload = true
        errorMessage = nil
        defer {
            isLoadingDownload = false
            isSavingDownload = false
        }
        do {
            let downloadedURL = try await session.downloadAttachment(attachment)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: downloadedURL, to: destination)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif
}
