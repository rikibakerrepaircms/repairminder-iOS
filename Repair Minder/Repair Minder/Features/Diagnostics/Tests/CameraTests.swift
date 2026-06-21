// Features/Diagnostics/Tests/CameraTests.swift
// Hardware cameras: Rear Camera (per-lens QR gate), Front Camera, Flash.
// Autofocus is now folded into the per-lens rear-camera QR test.
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

// MARK: - RearCameraTest

struct RearCameraTest: DiagnosticTest {
    let id = "rearcamera"; let name = "Rear Camera"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    /// Supported only when at least one physical rear lens is present — false on simulator.
    /// Uses AVCaptureDevice directly (not @MainActor CameraProbe) so isSupported stays nonisolated.
    var isSupported: Bool {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        ).devices.isEmpty == false
    }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? {
        AnyView(RearCameraTestView(complete: complete))
    }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - FrontCameraTest

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

// MARK: - FlashTest

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

// MARK: - Shared camera infrastructure (FrontCamera / Flash)

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

// MARK: - Per-lens Rear Camera ViewModel

/// Drives a sequential per-lens QR scan. Moves through each rear lens one by one.
/// A lens is marked passed the moment any QR/barcode is recognised through it.
/// When all lenses are done (or the user skips/fails), `outcome` is published.
@MainActor final class RearCameraViewModel: ObservableObject {
    struct LensState: Identifiable {
        let id: String          // "ultrawide" | "wide" | "tele"
        let device: AVCaptureDevice
        var passed: Bool?       // nil = pending, true = pass, false = fail (manual)
    }

    @Published var lenses: [LensState]
    @Published var activeIndex: Int = 0
    @Published var outcome: TestOutcome?
    @Published var denied = false

    private var probe: CameraProbe?
    private let testId: String
    private let testName: String

    init(testId: String, testName: String) {
        self.testId = testId
        self.testName = testName
        // CameraProbe.rearLenses() is @MainActor; this init is also @MainActor (class is @MainActor).
        self.lenses = CameraProbe.rearLenses().map { LensState(id: $0.type, device: $0.device) }
    }

    var activeLens: LensState? {
        guard activeIndex < lenses.count else { return nil }
        return lenses[activeIndex]
    }

    var activeProbeSession: AVCaptureSession? { probe?.previewSession }

    func startCurrentLens() {
        guard activeIndex < lenses.count else { return }
        let lens = lenses[activeIndex]
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            Task { @MainActor in
                guard granted else { self.denied = true; return }
                let p = CameraProbe(device: lens.device)
                self.probe = p
                p.start(onCode: { [weak self] _ in
                    Task { @MainActor in self?.markCurrentPassed() }
                })
            }
        }
    }

    private func markCurrentPassed() {
        guard activeIndex < lenses.count, lenses[activeIndex].passed == nil else { return }
        probe?.stop()
        probe = nil
        lenses[activeIndex].passed = true
        advance()
    }

    /// Called when user taps "Fail" to force-fail the current lens and move on.
    func failCurrentLens() {
        guard activeIndex < lenses.count, lenses[activeIndex].passed == nil else { return }
        probe?.stop()
        probe = nil
        lenses[activeIndex].passed = false
        advance()
    }

    private func advance() {
        let next = activeIndex + 1
        if next < lenses.count {
            activeIndex = next
            startCurrentLens()
        } else {
            finalize()
        }
    }

    private func finalize() {
        let perLens = Dictionary(uniqueKeysWithValues: lenses.map { ($0.id, $0.passed ?? false) })
        let (status, details) = RearCameraAggregate.result(perLens: perLens)
        outcome = diagnosticOutcome(testId, testName, status, details)
    }

    func skipAll() {
        probe?.stop()
        probe = nil
        outcome = diagnosticOutcome(testId, testName, .skip, nil)
    }

    func failAll() {
        probe?.stop()
        probe = nil
        outcome = diagnosticOutcome(testId, testName, .fail, ["reason": "user_failed"])
    }
}

// MARK: - Per-lens Rear Camera View

private struct RearCameraTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var model: RearCameraViewModel

    init(complete: @escaping (TestOutcome) -> Void) {
        self.complete = complete
        _model = StateObject(wrappedValue: RearCameraViewModel(testId: "rearcamera", testName: "Rear Camera"))
    }

    var body: some View {
        TestScaffold(
            title: "Rear Camera",
            instruction: "Point the rear camera at a QR or barcode. Each lens passes automatically once it recognises a code.",
            hints: ["Hold steady ~15 cm from a code"],
            allowManualPass: false,
            onPass: {},
            onFail: { model.failAll() },
            onSkip: { model.skipAll() }
        ) {
            VStack(spacing: 12) {
                // Live preview for the active lens
                if model.denied {
                    Label("Camera permission denied", systemImage: "xmark.circle").foregroundStyle(.red)
                } else if let session = model.activeProbeSession {
                    CameraPreview(session: session)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Per-lens checklist
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.lenses) { lens in
                        HStack(spacing: 8) {
                            Image(systemName: statusIcon(for: lens, activeIndex: model.activeIndex, lenses: model.lenses))
                                .foregroundStyle(statusColor(for: lens, activeIndex: model.activeIndex, lenses: model.lenses))
                            Text(displayName(for: lens.id))
                                .font(.subheadline)
                            if lens.id == model.activeLens?.id && lens.passed == nil {
                                Text("scanning…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)
            }
            .onAppear { model.startCurrentLens() }
            .onChange(of: model.outcome?.status) { _, _ in
                if let o = model.outcome { complete(o) }
            }
        }
    }

    private func displayName(for id: String) -> String {
        switch id {
        case "ultrawide": return "Ultra-wide"
        case "wide": return "Wide"
        case "tele": return "Telephoto"
        default: return id.capitalized
        }
    }

    private func statusIcon(for lens: RearCameraViewModel.LensState, activeIndex: Int, lenses: [RearCameraViewModel.LensState]) -> String {
        if let passed = lens.passed { return passed ? "checkmark.circle.fill" : "xmark.circle.fill" }
        let idx = lenses.firstIndex(where: { $0.id == lens.id }) ?? 0
        return idx == activeIndex ? "camera.viewfinder" : "circle"
    }

    private func statusColor(for lens: RearCameraViewModel.LensState, activeIndex: Int, lenses: [RearCameraViewModel.LensState]) -> Color {
        if let passed = lens.passed { return passed ? .green : .red }
        let idx = lenses.firstIndex(where: { $0.id == lens.id }) ?? 0
        return idx == activeIndex ? .blue : .secondary
    }
}

#endif
