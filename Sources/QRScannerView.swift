import SwiftUI
@preconcurrency import AVFoundation

private final class QRScannerController: NSObject, @unchecked Sendable, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.schoologytauri.qr-scanner", qos: .userInitiated)
    private var configured = false
    private var didDeliverCode = false

    var onCode: (@MainActor @Sendable (String) -> Void)?
    var onError: (@MainActor @Sendable (String) -> Void)?

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                configureAndStart()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard let self else { return }
                    queue.async {
                        if granted {
                            configureAndStart()
                        } else {
                            report("Camera access is disabled. Allow Schoology to use the camera in System Settings.")
                        }
                    }
                }
            default:
                report("Camera access is disabled. Allow Schoology to use the camera in System Settings.")
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configureAndStart() {
        guard !configured else {
            didDeliverCode = false
            if !session.isRunning { session.startRunning() }
            return
        }
        guard let camera = AVCaptureDevice.default(for: .video) else {
            report("No camera is available on this device.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            let output = AVCaptureMetadataOutput()
            session.beginConfiguration()
            session.sessionPreset = .high
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                report("Schoology couldn’t access the camera input.")
                return
            }
            session.addInput(input)
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                report("Schoology couldn’t start QR code scanning.")
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: queue)
            guard output.availableMetadataObjectTypes.contains(.qr) else {
                session.commitConfiguration()
                report("QR code scanning isn’t supported by this camera.")
                return
            }
            output.metadataObjectTypes = [.qr]
            session.commitConfiguration()
            configured = true
            session.startRunning()
        } catch {
            report("Unable to start the camera: \(error.localizedDescription)")
        }
    }

    private func report(_ message: String) {
        let callback = onError
        Task { @MainActor in callback?(message) }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didDeliverCode,
              let code = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
                .first(where: { $0.type == .qr })?.stringValue,
              !code.isEmpty else { return }
        didDeliverCode = true
        session.stopRunning()
        let callback = onCode
        Task { @MainActor in callback?(code) }
    }
}

struct QRCodeScannerView: View {
    let onCode: @MainActor @Sendable (String) -> Void

    @State private var scanner = QRScannerController()
    @State private var cameraError: String?

    var body: some View {
        VStack(spacing: 12) {
            if let cameraError {
                ContentUnavailableView(
                    "Camera unavailable",
                    systemImage: "camera.fill",
                    description: Text(cameraError)
                )
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                CameraPreview(session: scanner.session)
                    .clipShape(.rect(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                    }
                    .overlay(alignment: .center) {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.9), lineWidth: 2)
                            .frame(width: 190, height: 190)
                            .shadow(color: .black.opacity(0.25), radius: 8)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel("Live camera preview for scanning a Schoology QR code")
            }
        }
        .task {
            scanner.onCode = { value in onCode(value) }
            scanner.onError = { message in cameraError = message }
            scanner.start()
        }
        .onDisappear { scanner.stop() }
    }
}

#if os(iOS)
import UIKit

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) {
        if view.previewLayer.session !== session { view.previewLayer.session = session }
    }
}
#elseif os(macOS)
import AppKit

private final class CameraPreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        wantsLayer = true
        layer = previewLayer
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer = previewLayer
        previewLayer.videoGravity = .resizeAspectFill
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewView {
        CameraPreviewView(session: session)
    }

    func updateNSView(_ view: CameraPreviewView, context: Context) {
        if view.previewLayer.session !== session { view.previewLayer.session = session }
    }
}
#endif
