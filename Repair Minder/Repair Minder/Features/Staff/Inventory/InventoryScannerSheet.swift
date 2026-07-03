#if os(iOS)
import SwiftUI
@preconcurrency import AVFoundation
import AudioToolbox

/// Self-contained barcode scanner for inventory tag lookup.
///
/// Runs its own `AVCaptureSession` + `AVCaptureMetadataOutput` (mirroring the
/// setup used by the Devices `ScannerViewModel`) so it stays decoupled from the
/// Devices feature. On the first readable barcode it fires `onScan` once and
/// stops the session.
@MainActor
final class InventoryScannerModel: NSObject, ObservableObject {
    @Published var captureSession: AVCaptureSession?
    @Published var cameraPermissionDenied = false
    @Published var error: String?

    private var didScan = false
    var onScan: ((String) -> Void)?

    func setup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted { self?.configure() } else { self?.cameraPermissionDenied = true }
                }
            }
        case .denied, .restricted:
            cameraPermissionDenied = true
        @unknown default:
            cameraPermissionDenied = true
        }
    }

    private func configure() {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            error = "No camera available"; return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            self.error = "Could not create video input: \(error.localizedDescription)"; return
        }

        guard session.canAddInput(videoInput) else { error = "Could not add video input"; return }
        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { error = "Could not add metadata output"; return }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [
            .code128, .code39, .code93, .ean8, .ean13, .upce, .qr, .dataMatrix, .interleaved2of5
        ]

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }

    func stop() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.stopRunning()
        }
    }
}

extension InventoryScannerModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }

        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

        Task { @MainActor in
            guard !self.didScan else { return }
            self.didScan = true
            self.stop()
            self.onScan?(value)
        }
    }
}

/// Presents the inventory barcode scanner and returns the scanned string once.
struct InventoryScannerSheet: View {
    let onScan: (String) -> Void
    @StateObject private var model = InventoryScannerModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                if model.cameraPermissionDenied {
                    permissionDenied
                } else {
                    CameraPreviewView(session: model.captureSession)
                        .ignoresSafeArea()
                    frameOverlay
                }
            }
            .navigationTitle("Scan Asset Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            model.onScan = onScan
            model.setup()
        }
        .onDisappear { model.stop() }
    }

    private var frameOverlay: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 280, height: 280)
            Text("Point camera at the asset tag")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.top, 16)
            Spacer()
        }
    }

    private var permissionDenied: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill").font(.system(size: 60)).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("Camera Access Required").font(.headline)
                Text("Please enable camera access in Settings to scan asset tags")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button("Open Settings") { platformOpenSystemSettings() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
#endif
