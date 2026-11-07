import SwiftUI

struct SchoologyExternalToolEventView: View {
    @Environment(AppSession.self) private var session

    let sectionID: String
    let documentID: String
    let title: String

    @State private var destinationURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Opening external tool…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let destinationURL {
                SchoologyEmbeddedWebView(url: destinationURL, title: title)
            } else {
                ContentUnavailableView(
                    "Unable to open external tool",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage ?? "ClassWire could not load the external-tool launch URL.")
                )
            }
        }
        .navigationTitle(title)
        .task(id: "\(sectionID):\(documentID)") {
            isLoading = true
            errorMessage = nil
            destinationURL = nil
            do {
                destinationURL = try await session.loadExternalToolURL(sectionID: sectionID, documentID: documentID)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
