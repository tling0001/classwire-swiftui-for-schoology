import SwiftUI

struct SchoologyNotificationDocumentView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.openURL) private var openURL

    let realmID: String
    let documentID: String
    let title: String
    let documentType: String?
    let fallbackURL: URL?

    @State private var attachment: SchoologyAttachment?
    @State private var linkURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading document…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let attachment {
                SchoologyAttachmentPreviewButton(attachment: attachment, automaticallyPresent: true)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if let destination = linkURL ?? fallbackURL {
                VStack(alignment: .leading, spacing: 12) {
                    Label(title, systemImage: documentType?.lowercased() == "link" ? "link" : "doc")
                        .font(.headline)
                    Button {
                        openURL(destination)
                    } label: {
                        Label("Open in Browser", systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    "Unable to open document",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage ?? "Schoology did not return a file or link for this item.")
                )
            }
        }
        .navigationTitle(title)
        .task(id: documentID) { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await session.loadNotificationDocument(
                realmID: realmID,
                documentID: documentID,
                title: title,
                documentTypeHint: documentType
            )
            attachment = result.attachment
            linkURL = result.linkURL
            if attachment == nil && linkURL == nil && fallbackURL == nil {
                errorMessage = "Schoology did not return a file or link for this item."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
