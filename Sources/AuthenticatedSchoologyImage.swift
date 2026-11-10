import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct AuthenticatedSchoologyImage: View {
    @Environment(AppSession.self) private var session
    @State private var imageData: Data?
    @State private var didFail = false
    let url: URL
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let imageData { platformImage(from: imageData) }
            else if didFail { imageFailure }
            else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
                    .accessibilityLabel("Loading image")
            }
        }
        .task(id: url) {
            imageData = nil
            didFail = false
            guard let auth = session.auth else { didFail = true; return }
            do {
                guard let loaded = try await SchoologyAPI.shared.imageData(url, auth: auth) else {
                    didFail = true
                    return
                }
                try Task.checkCancellation()
                imageData = loaded
            } catch is CancellationError {
                // A replacement task owns the state after this row disappears or changes URL.
            } catch {
                didFail = true
            }
        }
    }

    @ViewBuilder
    private func platformImage(from data: Data) -> some View {
        #if os(iOS)
        if let image = UIImage(data: data) {
            Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
        } else { imageFailure }
        #elseif os(macOS)
        if let image = NSImage(data: data) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: contentMode)
        } else { imageFailure }
        #else
        imageFailure
        #endif
    }

    private var imageFailure: some View {
        Image(systemName: "photo")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
            .accessibilityLabel("Image unavailable")
    }
}
