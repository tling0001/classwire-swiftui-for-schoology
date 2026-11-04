import SwiftUI
import QuickLook

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
        .presentationDetents(attachments.count > 5 ? [.medium, .large] : [.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct SchoologyAttachmentActionRow: View {
    @Environment(AppSession.self) private var session
    let attachment: SchoologyAttachment
    @State private var previewURL: URL?
    @State private var downloadedURL: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(attachment.title, systemImage: icon).font(.subheadline.weight(.medium)).lineLimit(2)
            HStack(spacing: 12) {
                Button { Task { await load(forViewing: true) } } label: {
                    Label("View", systemImage: "eye").frame(minWidth: 72, minHeight: 40)
                }.buttonStyle(.bordered).disabled(isLoading)
                Button { Task { await load(forViewing: false) } } label: {
                    if isLoading { ProgressView().frame(minWidth: 90, minHeight: 40) }
                    else { Label("Download", systemImage: "arrow.down.to.line").frame(minWidth: 90, minHeight: 40) }
                }.buttonStyle(.bordered).disabled(isLoading)
                if let downloadedURL {
                    ShareLink(item: downloadedURL) {
                        Image(systemName: "square.and.arrow.down").frame(minWidth: 44, minHeight: 44)
                    }.accessibilityLabel("Save or share downloaded attachment")
                }
            }
            if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
        }
        .padding(.vertical, 5)
        .quickLookPreview($previewURL)
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
    @MainActor private func load(forViewing: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let url = try await session.downloadAttachment(attachment)
            if forViewing { previewURL = url } else { downloadedURL = url }
        } catch { errorMessage = error.localizedDescription }
    }
}
