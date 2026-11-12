import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

/// Image bytes ready to be uploaded through the existing Schoology file service.
struct SchoologyComposerImage: Identifiable, Sendable {
    let id: UUID
    let data: Data
    let filename: String
    let mimeType: String

    init(data: Data, filename: String, mimeType: String) {
        self.id = UUID()
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
    }
}

/// Shared photo actions for composers. PhotosPicker is privacy-preserving and
/// grants access only to the items the user selects. Camera capture is offered
/// on iOS/iPadOS only when the device reports a camera is available.
struct SchoologyComposerMediaPicker: View {
    let isDisabled: Bool
    let onImagesPicked: ([SchoologyComposerImage]) async -> Void
    let onError: (String) -> Void
    let onActivityChanged: (Bool) -> Void

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var showingCamera = false

    var body: some View {
        Section("Photos") {
            #if os(iOS)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera", systemImage: "camera") {
                    showingCamera = true
                }
                .disabled(isDisabled || isLoadingPhotos)
                .accessibilityHint("Take a new photo to attach")
            }
            #endif

            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            ) {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }
            .disabled(isDisabled || isLoadingPhotos)
            .accessibilityHint("Choose photos to attach")
            if isLoadingPhotos {
                ProgressView("Preparing photos…")
            }
        }
        .onChange(of: selectedPhotos) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPhotos(items) }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingCamera) {
            SchoologyCameraCaptureView(
                onCapture: { data in
                    let image = SchoologyComposerImage(
                        data: data,
                        filename: "Camera-\(UUID().uuidString.prefix(8)).jpg",
                        mimeType: "image/jpeg"
                    )
                    onActivityChanged(true)
                    Task {
                        await onImagesPicked([image])
                        onActivityChanged(false)
                    }
                },
                onDismiss: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        #endif
    }

    @MainActor
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        guard !isLoadingPhotos else { return }
        isLoadingPhotos = true
        onActivityChanged(true)
        defer {
            isLoadingPhotos = false
            selectedPhotos = []
            onActivityChanged(false)
        }

        var images: [SchoologyComposerImage] = []
        do {
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                    continue
                }
                let type = item.supportedContentTypes.first ?? .jpeg
                let fileExtension = type.preferredFilenameExtension ?? "jpg"
                let filename = "Photo-\(UUID().uuidString.prefix(8)).\(fileExtension)"
                images.append(SchoologyComposerImage(
                    data: data,
                    filename: filename,
                    mimeType: type.preferredMIMEType ?? "image/jpeg"
                ))
            }
            if !images.isEmpty {
                await onImagesPicked(images)
            } else if !items.isEmpty {
                onError("The selected photos could not be read.")
            }
        } catch {
            onError("Could not load the selected photos: \(error.localizedDescription)")
        }
    }
}

#if os(iOS)
/// Wraps Apple's full-screen system camera interface; the Photos library uses
/// the native SwiftUI PhotosPicker above.
private struct SchoologyCameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.mediaTypes = [UTType.image.identifier]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data) -> Void
        private let onDismiss: () -> Void

        init(onCapture: @escaping (Data) -> Void, onDismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onDismiss = onDismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.88) {
                onCapture(data)
            }
            picker.dismiss(animated: true, completion: onDismiss)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true, completion: onDismiss)
        }
    }
}
#endif
