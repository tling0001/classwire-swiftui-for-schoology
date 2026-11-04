import SwiftUI
import QuickLook

struct SchoologyAttachmentPreviewButton: View {
    @Environment(AppSession.self) private var session
    let attachment: SchoologyAttachment
    @State private var previewURL: URL?
    @State private var isDownloading = false
    @State private var errorMessage: String?

    var body: some View {
        Button {
            guard !isDownloading else { return }
            isDownloading = true
            errorMessage = nil
            Task {
                defer { isDownloading = false }
                do { previewURL = try await session.downloadAttachment(attachment) }
                catch { errorMessage = error.localizedDescription }
            }
        } label: {
            HStack(spacing: 7) {
                if isDownloading { ProgressView().controlSize(.small) }
                else { Image(systemName: "paperclip").accessibilityHidden(true) }
                Text(attachment.title).lineLimit(2).multilineTextAlignment(.leading)
            }
            .font(.caption)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
        .accessibilityHint("Downloads and previews this attachment")
        .quickLookPreview($previewURL)
        .alert("Unable to Preview Attachment", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }
}
