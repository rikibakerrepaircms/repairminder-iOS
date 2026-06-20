// Features/Diagnostics/Tests/CameraTests.swift
// M360-parity "Hardware" cameras: Rear Camera, Front Camera, Autofocus (QR auto-pass), Flash.
// Camera hardware is absent on the simulator → these report unsupported there; device-verified.
import SwiftUI
#if os(iOS)
import AVFoundation
import UIKit
#endif

#if os(iOS)
private func hasCamera(_ position: AVCaptureDevice.Position) -> Bool {
    AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) != nil
}
private func hasTorch() -> Bool {
    AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)?.hasTorch ?? false
}
#endif

struct RearCameraTest: DiagnosticTest {
    let id = "rearcamera"; let name = "Rear Camera"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { hasCamera(.back) }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(CameraTestView(id: id, name: name, position: .back, mode: .preview, complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

struct FrontCameraTest: DiagnosticTest {
    let id = "frontcamera"; let name = "Front Camera"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { hasCamera(.front) }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(CameraTestView(id: id, name: name, position: .front, mode: .preview, complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

struct AutofocusTest: DiagnosticTest {
    let id = "autofocus"; let name = "Autofocus"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { hasCamera(.back) }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(CameraTestView(id: id, name: name, position: .back, mode: .qr, complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

struct FlashTest: DiagnosticTest {
    let id = "flash"; let name = "Flash"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { hasTorch() }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(CameraTestView(id: id, name: name, position: .back, mode: .torch, complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

#if os(iOS)

enum CameraTestMode { case preview, qr, torch }

@MainActor final class CameraController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    @Published var detectedCode: String?
    @Published var denied = false
    private let queue = DispatchQueue(label: "diagnostics.camera")
    private var device: AVCaptureDevice?

    func configureAndStart(position: AVCaptureDevice.Position, mode: CameraTestMode) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else { Task { @MainActor in self.denied = true }; return }
            self.queue.async { self.setup(position: position, mode: mode) }
        }
    }

    private func setup(position: AVCaptureDevice.Position, mode: CameraTestMode) {
        session.beginConfiguration()
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: dev), session.canAddInput(input) else {
            session.commitConfiguration(); return
        }
        session.addInput(input)
        device = dev
        if mode == .qr {
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.qr, .ean13, .code128, .aztec, .pdf417]
            }
        }
        session.commitConfiguration()
        session.startRunning()
        if mode == .torch { setTorch(true) }
    }

    func setTorch(_ on: Bool) {
        guard let dev = device, dev.hasTorch else { return }
        try? dev.lockForConfiguration()
        dev.torchMode = on ? .on : .off
        dev.unlockForConfiguration()
    }

    func stop() {
        if device?.hasTorch == true { setTorch(false) }
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = objects.first as? AVMetadataMachineReadableCodeObject, let s = obj.stringValue else { return }
        Task { @MainActor in self.detectedCode = s }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView { let v = PreviewView(); v.videoPreviewLayer.session = session; v.videoPreviewLayer.videoGravity = .resizeAspectFill; return v }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

private struct CameraTestView: View {
    let id: String; let name: String
    let position: AVCaptureDevice.Position
    let mode: CameraTestMode
    let complete: (TestOutcome) -> Void
    @StateObject private var cam = CameraController()

    private var instruction: String {
        switch mode {
        case .preview: return "Check the live camera image is clear and correct, then tap Pass."
        case .qr: return "Point the rear camera at a QR or barcode. It passes automatically once focused and recognised."
        case .torch: return "The flashlight should be on — check the LED on the back of the device, then tap Pass."
        }
    }

    var body: some View {
        TestScaffold(
            title: name,
            instruction: instruction,
            hints: mode == .qr ? ["Hold steady ~15cm from a code"] : [],
            allowManualPass: mode != .qr,   // QR auto-passes; preview/torch are subjective
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            ZStack {
                if cam.denied {
                    Label("Camera permission denied", systemImage: "xmark.circle").foregroundStyle(.red)
                } else {
                    CameraPreview(session: cam.session)
                        .frame(height: 320).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if mode == .qr, let code = cam.detectedCode {
                    Text("Recognised: \(code)").font(.caption).padding(6).background(.green).foregroundStyle(.white).clipShape(Capsule())
                }
            }
            .onAppear { cam.configureAndStart(position: position, mode: mode) }
            .onChange(of: cam.detectedCode) { _, code in
                if mode == .qr, code != nil { finish(.pass, ["recognised": "1"]) }
            }
        }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) { cam.stop(); complete(diagnosticOutcome(id, name, s, d)) }
}
#endif
