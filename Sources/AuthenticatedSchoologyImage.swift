import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct AuthenticatedSchoologyImage: View {
    @Environment(AppSession.self) private var session
    @State private var imageData: Data?

    let url: URL
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let imageData {
                platformImage(from: imageData)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .task(id: url) {
            guard let auth = session.auth else { return }
            imageData = try? await SchoologyAPI.shared.imageData(url, auth: auth)
        }
    }

    @ViewBuilder
    private func platformImage(from data: Data) -> some View {
        #if os(iOS)
        if let image = UIImage(data: data) {
            Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
        } else {
            imageFailure
        }
        #elseif os(macOS)
        if let image = NSImage(data: data) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: contentMode)
        } else {
            imageFailure
        }
        #else
        imageFailure
        #endif
    }

    private var imageFailure: some View {
        Image(systemName: "photo")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
    }
}
