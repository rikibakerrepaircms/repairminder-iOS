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

/// Drives a depth-frame probe, auto-passing once ≥3 frames arrive.
/// Injected with a `DepthProbe` so it can be tested with a fake.
@MainActor final class DepthViewModel: ObservableObject {
    private let probe: DepthProbe
    private let id: String
    private let name: String
    private let detailKey: String
    @Published var frames = 0
    @Published var outcome: TestOutcome?

    init(probe: DepthProbe, id: String, name: String, detailKey: String) {
        self.probe = probe; self.id = id; self.name = name; self.detailKey = detailKey
    }

    func start() {
        probe.start(onDepthFrame: { [weak self] in
            guard let self, self.outcome == nil else { return }
            self.frames += 1
            if self.frames >= 3 {
                self.outcome = diagnosticOutcome(self.id, self.name, .pass, [self.detailKey: String(self.frames)])
                self.probe.stop()
            }
        })
    }

    func fail() { probe.stop(); outcome = diagnosticOutcome(id, name, .fail, nil) }
    func skip() { probe.stop(); outcome = diagnosticOutcome(id, name, .skip, nil) }
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
            instruction: "Point the front TrueDepth camera at your face or an object — it passes automatically when depth frames are captured.",
            hints: ["Used by Face ID and Portrait selfies"],
            allowManualPass: false,
            onPass: {},
            onFail: { model.fail() },
            onSkip: { model.skip() }
        ) {
            VStack(spacing: 8) {
                Image(systemName: "faceid").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                Text("Depth frames: \(model.frames)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .onAppear { model.start() }
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
            instruction: "Point the device at nearby objects — it passes automatically when the LiDAR scene-depth stream produces frames.",
            hints: ["LiDAR is used for depth, AR and low-light autofocus"],
            allowManualPass: false,
            onPass: {},
            onFail: { model.fail() },
            onSkip: { model.skip() }
        ) {
            VStack(spacing: 8) {
                Image(systemName: "cube.transparent").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                Text("Depth frames: \(model.frames)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .onAppear { model.start() }
        .onChange(of: model.outcome?.status) { _, _ in
            if let o = model.outcome { complete(o) }
        }
    }
}
#endif
