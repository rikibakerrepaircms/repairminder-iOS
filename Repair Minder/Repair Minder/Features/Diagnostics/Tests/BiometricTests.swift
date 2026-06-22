// Features/Diagnostics/Tests/BiometricTests.swift
// Hardware: Biometric (Face ID/Touch ID, auto), TrueDepth Camera, LiDAR Scanner.
import SwiftUI
#if os(iOS)
import LocalAuthentication
import AVFoundation
import ARKit
#endif

// MARK: - Biometric (LAContext — auto-pass on successful authentication)

struct BiometricTest: DiagnosticTest {
    let id = "biometric"; let name = "Biometric Sensor"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(BiometricTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - TrueDepth Camera

struct TrueDepthTest: DiagnosticTest {
    let id = "truedepth"; let name = "TrueDepth Camera"; let category: TestCategory = .hardware
    var requiredPermissions: [DiagnosticPermission] { [.camera] }
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) != nil }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(TrueDepthTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - LiDAR Scanner

struct LiDARTest: DiagnosticTest {
    let id = "lidar"; let name = "LiDAR Scanner"; let category: TestCategory = .hardware
    var requiredPermissions: [DiagnosticPermission] { [.camera] }
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(LiDARTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

#if os(iOS)

// MARK: - DepthViewModel (shared by TrueDepth and LiDAR tests)

/// Drives a depth-frame probe, requiring ~3 seconds of depth signal before passing.
/// Injected with a `DepthProbe` so it can be tested with a fake.
@MainActor final class DepthViewModel: ObservableObject {
    private let probe: DepthProbe
    private let id: String
    private let name: String
    private let detailKey: String
    private let requiredSeconds: Int
    private let minFrames: Int
    @Published var frames = 0
    @Published var depthImage: CGImage?
    @Published var secondsLeft: Int
    @Published var outcome: TestOutcome?
    private var startTime: Date?
    private var ticker: Timer?

    init(probe: DepthProbe, id: String, name: String, detailKey: String,
         requiredSeconds: Int = 3, minFrames: Int = 30) {
        self.probe = probe; self.id = id; self.name = name; self.detailKey = detailKey
        self.requiredSeconds = requiredSeconds; self.minFrames = minFrames
        self.secondsLeft = requiredSeconds
    }

    func start() {
        probe.start(onDepthFrame: { [weak self] in
            guard let self, self.outcome == nil else { return }
            self.frames += 1
            if self.startTime == nil { self.beginCountdown() }
            self.checkPass()
        }, onDepthImage: { [weak self] img in
            guard let self, self.outcome == nil else { return }
            self.depthImage = img
        })
    }

    private func beginCountdown() {
        startTime = Date()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let s = self.startTime else { return }
                let elapsed = Date().timeIntervalSince(s)
                self.secondsLeft = max(0, self.requiredSeconds - Int(elapsed))
                self.checkPass()
            }
        }
    }

    private func checkPass() {
        guard outcome == nil, let s = startTime else { return }
        let elapsed = Date().timeIntervalSince(s)
        if elapsed >= Double(requiredSeconds), frames >= minFrames {
            ticker?.invalidate(); ticker = nil
            outcome = diagnosticOutcome(id, name, .pass,
                [detailKey: String(frames), "duration_s": String(format: "%.1f", elapsed)])
            probe.stop()
        }
    }

    func fail() {
        ticker?.invalidate(); ticker = nil
        probe.stop()
        outcome = diagnosticOutcome(id, name, .fail, nil)
    }

    func skip() {
        ticker?.invalidate(); ticker = nil
        probe.stop()
        outcome = diagnosticOutcome(id, name, .skip, nil)
    }

    /// Auto-fail dead hardware that never produced depth frames (call from a watchdog Task).
    func failIfUnresolved() {
        guard outcome == nil else { return }
        ticker?.invalidate(); ticker = nil
        probe.stop()
        outcome = diagnosticOutcome(id, name, .fail, ["reason": "no_depth_signal"])
    }
}

// MARK: - BiometricController

@MainActor private final class BiometricController: ObservableObject {
    @Published var status: String = "Ready"
    func authenticate(_ done: @escaping (Bool, String, String) -> Void) {
        let ctx = LAContext()
        let kind: String
        switch ctx.biometryType {
        case .faceID: kind = "faceid"
        case .touchID: kind = "touchid"
        default: kind = "unknown"
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Verify the biometric sensor") { ok, err in
            // Use a fresh context for canEvaluatePolicy; the original may be consumed.
            let statusCtx = LAContext()
            let faceIDStatus = statusCtx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ? "active" : "inactive"
            Task { @MainActor in done(ok, kind, faceIDStatus); if let err { self.status = err.localizedDescription } }
        }
    }
}

private struct BiometricTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var ctrl = BiometricController()
    @State private var completed = false
    @State private var authInFlight = false

    var body: some View {
        TestScaffold(
            title: "Biometric Sensor",
            instruction: "Authenticate with Face ID / Touch ID. It passes automatically on a successful match.",
            hints: ["Requires biometrics enrolled on the device"],
            onPass: { finish(.pass, nil) },
            onFail: { finish(.fail, nil) },
            onSkip: { finish(.skip, nil) }
        ) {
            VStack(spacing: 12) {
                Image(systemName: "faceid").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                Button("Authenticate") {
                    guard !authInFlight, !completed else { return }
                    authInFlight = true
                    ctrl.authenticate { ok, kind, faceIDStatus in
                        authInFlight = false
                        finish(ok ? .pass : .fail, ["type": kind, "faceid_status": faceIDStatus])
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authInFlight)
                Text(ctrl.status).font(.caption).foregroundStyle(.secondary)
            }
            .onAppear {
                guard !completed, !authInFlight else { return }
                authInFlight = true
                ctrl.authenticate { ok, kind, faceIDStatus in
                    authInFlight = false
                    if ok { finish(.pass, ["type": kind, "faceid_status": faceIDStatus]) }
                }
            }
        }
    }

    private func finish(_ s: TestStatus, _ d: [String: String]?) {
        guard !completed else { return }
        completed = true
        complete(diagnosticOutcome("biometric", "Biometric Sensor", s, d))
    }
}

private struct TrueDepthTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var model = DepthViewModel(
        probe: TrueDepthProbe(),
        id: "truedepth",
        name: "TrueDepth Camera",
        detailKey: "depth_frames"
    )
    var body: some View {
        TestScaffold(
            title: "TrueDepth Camera",
            instruction: "Move the device around so the front TrueDepth sensor scans depth — passes after ~3 seconds.",
            hints: ["Used by Face ID and Portrait selfies"],
            allowManualPass: false,
            onPass: {},
            onFail: { model.fail() },
            onSkip: { model.skip() }
        ) {
            VStack(spacing: 12) {
                if let cg = model.depthImage {
                    Image(decorative: cg, scale: 1.0, orientation: .right)
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.4)))
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray6))
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .overlay(ProgressView("Starting depth sensor…"))
                }
                Text(model.secondsLeft > 0 ? "Move the device around… \(model.secondsLeft)s"
                                           : "Hold steady — finishing…")
                    .font(.subheadline.weight(.semibold))
                Text("Depth frames: \(model.frames)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .onAppear {
                model.start()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    model.failIfUnresolved()
                }
            }
        }
        .onChange(of: model.outcome?.status) { _, _ in
            if let o = model.outcome { complete(o) }
        }
    }
}

private struct LiDARTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var model = DepthViewModel(
        probe: LiDARProbe(),
        id: "lidar",
        name: "LiDAR Scanner",
        detailKey: "scene_depth_frames"
    )
    var body: some View {
        TestScaffold(
            title: "LiDAR Scanner",
            instruction: "Move the device around so the LiDAR sensor scans depth — passes after ~3 seconds.",
            hints: ["LiDAR is used for depth, AR and low-light autofocus"],
            allowManualPass: false,
            onPass: {},
            onFail: { model.fail() },
            onSkip: { model.skip() }
        ) {
            VStack(spacing: 12) {
                if let cg = model.depthImage {
                    Image(decorative: cg, scale: 1.0, orientation: .right)
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.4)))
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray6))
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .overlay(ProgressView("Starting depth sensor…"))
                }
                Text(model.secondsLeft > 0 ? "Move the device around… \(model.secondsLeft)s"
                                           : "Hold steady — finishing…")
                    .font(.subheadline.weight(.semibold))
                Text("Depth frames: \(model.frames)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .onAppear {
                model.start()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    model.failIfUnresolved()
                }
            }
        }
        .onChange(of: model.outcome?.status) { _, _ in
            if let o = model.outcome { complete(o) }
        }
    }
}
#endif
