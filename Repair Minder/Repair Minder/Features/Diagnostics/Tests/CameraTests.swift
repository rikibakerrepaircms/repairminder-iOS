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

// MARK: - Camera target constant

/// Page that displays a large QR focus target; the technician opens it on a SECOND device,
/// then points the device-under-test's camera at it. (Served by the RepairMinder Worker,
/// Turnstile-gated + rate-limited.) Any QR/barcode works as a fallback if this page is unreachable.
let cameraTargetURL = "https://api.repairminder.com/camera-test"

// MARK: - Camera target help overlay

/// A compact overlay button that expands (sheet) to show a QR the technician can scan
/// on a second device to open the camera-test target page.
private struct CameraTargetHelp: View {
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Label("Need a QR to scan?", systemImage: "qrcode")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.primary)
        }
        .sheet(isPresented: $showSheet) {
            CameraTargetHelpSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct CameraTargetHelpSheet: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Open on another device")
                .font(.headline)
            Text("On another device, open:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(cameraTargetURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            QRCodeImage(string: cameraTargetURL, side: 140)
            Text("Point this device's camera at the QR code on that screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
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
    var isSupported: Bool {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front).devices.first != nil
    }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(FrontCameraTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - FlashTest

struct FlashTest: DiagnosticTest {
    let id = "flash"; let name = "Flash"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)?.hasTorch ?? false
    }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(FlashTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

#if os(iOS)

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView { let v = PreviewView(); v.videoPreviewLayer.session = session; v.videoPreviewLayer.videoGravity = .resizeAspectFill; return v }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
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
    /// Published so the view re-renders when the active lens's probe (and its session) changes.
    @Published private(set) var activeProbeSession: AVCaptureSession?

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

    func startCurrentLens() {
        guard activeIndex < lenses.count else { return }
        let lens = lenses[activeIndex]
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            Task { @MainActor in
                guard granted else { self.denied = true; return }
                let p = CameraProbe(device: lens.device)
                self.probe = p
                // Publish the session BEFORE starting the probe so the preview layer
                // is attached to the session by the time startRunning() fires.
                self.activeProbeSession = p.previewSession
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
        activeProbeSession = nil
        lenses[activeIndex].passed = true
        advance()
    }

    /// Called when user taps "Fail" to force-fail the current lens and move on.
    func failCurrentLens() {
        guard activeIndex < lenses.count, lenses[activeIndex].passed == nil else { return }
        probe?.stop()
        probe = nil
        activeProbeSession = nil
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
        activeProbeSession = nil
        outcome = diagnosticOutcome(testId, testName, .skip, nil)
    }

    func failAll() {
        probe?.stop()
        probe = nil
        activeProbeSession = nil
        outcome = diagnosticOutcome(testId, testName, .fail, ["reason": "user_failed"])
    }
}

// MARK: - Front Camera ViewModel

@MainActor final class FrontCameraViewModel: ObservableObject {
    private let probe: QRProbe
    @Published var outcome: TestOutcome?
    @Published var qrSeen = false

    /// Exposed for the live preview layer; nil when probe is a test double.
    var previewSession: AVCaptureSession? { (probe as? CameraProbe)?.previewSession }

    init(probe: QRProbe) { self.probe = probe }
    func start() {
        probe.start(onCode: { [weak self] _ in
            guard let self, self.outcome == nil else { return }
            self.qrSeen = true
            self.outcome = diagnosticOutcome("frontcamera", "Front Camera", .pass, ["qr_detected": "1"])
            self.probe.stop()
        })
    }
    func fail() { probe.stop(); outcome = diagnosticOutcome("frontcamera", "Front Camera", .fail, nil) }
    func skip() { probe.stop(); outcome = diagnosticOutcome("frontcamera", "Front Camera", .skip, nil) }
}

// MARK: - Front Camera View

private struct FrontCameraTestView: View {
    let complete: (TestOutcome) -> Void
    private let probe: CameraProbe?

    init(complete: @escaping (TestOutcome) -> Void) {
        self.complete = complete
        self.probe = CameraProbe.front().map { CameraProbe(device: $0) }
    }

    var body: some View {
        if let probe {
            FrontCameraActiveView(probe: probe, complete: complete)
        } else {
            Color.clear.onAppear {
                complete(diagnosticOutcome("frontcamera", "Front Camera", .skip, ["reason": "no_front_camera"]))
            }
        }
    }
}

private struct FrontCameraActiveView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var model: FrontCameraViewModel

    init(probe: CameraProbe, complete: @escaping (TestOutcome) -> Void) {
        self.complete = complete
        _model = StateObject(wrappedValue: FrontCameraViewModel(probe: probe))
    }

    var body: some View {
        TestScaffold(
            title: "Front Camera",
            instruction: "Point the front camera at a QR/barcode — it passes automatically once recognised.",
            hints: [],
            allowManualPass: false,
            fullBleed: true,
            onPass: {},
            onFail: { model.fail() },
            onSkip: { model.skip() }
        ) {
            ZStack(alignment: .top) {
                // Full-screen live preview
                if let session = model.previewSession {
                    CameraPreview(session: session)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(edges: .horizontal)
                }

                // Compact overlay: QR-detected indicator + help button
                HStack {
                    if model.qrSeen {
                        Label("QR detected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.green.opacity(0.85), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    CameraTargetHelp()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
        }
        .onAppear { model.start() }
        .onChange(of: model.outcome?.status) { _, _ in
            if let o = model.outcome { complete(o) }
        }
    }
}

// MARK: - Flash View

private struct FlashTestView: View {
    let complete: (TestOutcome) -> Void

    @State private var probe: CameraProbe? = nil
    @State private var baseline: Double? = nil
    @State private var showManualPass = false
    @State private var completed = false

    private func finish(_ status: TestStatus, _ details: [String: String]?) {
        guard !completed else { return }
        completed = true
        probe?.setTorch(false)
        probe?.stop()
        probe = nil
        complete(diagnosticOutcome("flash", "Flash", status, details))
    }

    var body: some View {
        TestScaffold(
            title: "Flash",
            instruction: showManualPass
                ? "If the flash lit up, tap Pass."
                : "Testing flash automatically via rear camera…",
            hints: [],
            allowManualPass: showManualPass,
            onPass: { finish(.pass, ["auto_detected": "0"]) },
            onFail: { finish(.fail, nil) },
            onSkip: { finish(.skip, nil) }
        ) {
            if showManualPass {
                Text("Flash test completed. Did the LED light up?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView("Analysing flash…")
                    .padding()
            }
        }
        .onAppear {
            guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                finish(.skip, nil); return
            }
            let p = CameraProbe(device: dev)
            probe = p

            // Phase timing (wall-clock, so actual frame rate doesn't matter):
            //  0.0 – 0.8s  → collect baseline
            //  0.8s         → torch ON
            //  0.8 – 1.4s  → settle delay (auto-exposure stabilises — do NOT sample)
            //  1.4 – 4.4s  → sample window: auto-pass if ≥25% luminance jump
            //  4.4s         → reveal manual-pass button
            let baselineDuration:  Double = 0.8
            let settleDuration:    Double = 0.6   // after torch on
            let sampleDuration:    Double = 3.0   // sample window length

            let startTime = Date()
            var baselineAccum: Double = 0
            var baselineSamples = 0
            var torchLit = false
            var torchOnTime: Date? = nil
            var peakAfterSettle: Double = 0

            p.start(onSample: { luma in
                let elapsed = Date().timeIntervalSince(startTime)

                if elapsed < baselineDuration {
                    // Phase 1: collect baseline
                    baselineAccum += luma
                    baselineSamples += 1
                } else if !torchLit {
                    // Phase 2: turn torch on once
                    p.setTorch(true)
                    torchLit = true
                    torchOnTime = Date()
                } else if let lit = torchOnTime {
                    let sinceOn = Date().timeIntervalSince(lit)
                    if sinceOn >= settleDuration {
                        // Phase 3: sample window — compare against baseline
                        peakAfterSettle = max(peakAfterSettle, luma)
                        let base = baselineAccum / Double(max(1, baselineSamples))
                        if FlashDecision.shouldAutoPass(baseline: base, peak: peakAfterSettle) {
                            finish(.pass, ["auto_detected": "1"])
                        }
                    }
                    // else: still in settle window — skip sample
                }
            })

            // After full window (baseline + torch-on + sample), reveal manual pass
            let totalWindow = baselineDuration + settleDuration + sampleDuration
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(totalWindow * 1_000_000_000))
                guard !completed else { return }
                showManualPass = true
            }
        }
        .onDisappear {
            if !completed { finish(.skip, nil) }
        }
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
            fullBleed: true,
            onPass: {},
            onFail: { model.failAll() },
            onSkip: { model.skipAll() }
        ) {
            ZStack(alignment: .top) {
                // Full-screen live preview for the active lens
                if model.denied {
                    Color.black
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            Label("Camera permission denied", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                        }
                } else if let session = model.activeProbeSession {
                    CameraPreview(session: session)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(edges: .horizontal)
                        // Re-renders when the active probe changes (session identity changes)
                        .id(model.activeIndex)
                }

                // Compact overlay: per-lens progress + QR target help
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(alignment: .top) {
                        // Per-lens status pill
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(model.lenses) { lens in
                                HStack(spacing: 5) {
                                    Image(systemName: statusIcon(for: lens, activeIndex: model.activeIndex, lenses: model.lenses))
                                        .foregroundStyle(statusColor(for: lens, activeIndex: model.activeIndex, lenses: model.lenses))
                                        .imageScale(.small)
                                    Text(displayName(for: lens.id))
                                        .font(.caption.weight(.medium))
                                    if lens.id == model.activeLens?.id && lens.passed == nil {
                                        Text("scanning…")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                        Spacer()

                        CameraTargetHelp()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
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
