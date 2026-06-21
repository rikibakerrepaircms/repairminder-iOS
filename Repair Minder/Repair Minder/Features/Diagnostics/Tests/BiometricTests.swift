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
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(LiDARTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

#if os(iOS)

@MainActor private final class BiometricController: ObservableObject {
    @Published var status: String = "Ready"
    func authenticate(_ done: @escaping (Bool, String) -> Void) {
        let ctx = LAContext()
        let kind: String
        switch ctx.biometryType {
        case .faceID: kind = "faceid"
        case .touchID: kind = "touchid"
        default: kind = "unknown"
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Verify the biometric sensor") { ok, err in
            Task { @MainActor in done(ok, kind); if let err { self.status = err.localizedDescription } }
        }
    }
}

private struct BiometricTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var ctrl = BiometricController()

    var body: some View {
        TestScaffold(
            title: "Biometric Sensor",
            instruction: "Authenticate with Face ID / Touch ID. It passes automatically on a successful match.",
            hints: ["Requires biometrics enrolled on the device"],
            onPass: { complete(diagnosticOutcome("biometric", "Biometric Sensor", .pass)) },
            onFail: { complete(diagnosticOutcome("biometric", "Biometric Sensor", .fail)) },
            onSkip: { complete(diagnosticOutcome("biometric", "Biometric Sensor", .skip)) }
        ) {
            VStack(spacing: 12) {
                Image(systemName: "faceid").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                Button("Authenticate") {
                    ctrl.authenticate { ok, kind in
                        complete(diagnosticOutcome("biometric", "Biometric Sensor", ok ? .pass : .fail, ["type": kind]))
                    }
                }
                .buttonStyle(.borderedProminent)
                Text(ctrl.status).font(.caption).foregroundStyle(.secondary)
            }
            .onAppear { ctrl.authenticate { ok, kind in if ok { complete(diagnosticOutcome("biometric", "Biometric Sensor", .pass, ["type": kind])) } } }
        }
    }
}

private struct TrueDepthTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var cam = CameraController()
    var body: some View {
        TestScaffold(
            title: "TrueDepth Camera",
            instruction: "The front TrueDepth camera feed is shown. Confirm a clear image, then tap Pass.",
            hints: ["Used by Face ID and Portrait selfies"],
            allowManualPass: true,
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            CameraPreview(session: cam.session).frame(height: 320).clipShape(RoundedRectangle(cornerRadius: 12))
                .onAppear { cam.configureAndStart(position: .front, mode: .preview) }
        }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) { cam.stop(); complete(diagnosticOutcome("truedepth", "TrueDepth Camera", s, d)) }
}

private struct LiDARTestView: View {
    let complete: (TestOutcome) -> Void
    var body: some View {
        TestScaffold(
            title: "LiDAR Scanner",
            instruction: "This device reports a LiDAR scanner. Point it at nearby objects to confirm depth scanning works, then tap Pass.",
            hints: ["LiDAR is used for depth, AR and low-light autofocus"],
            allowManualPass: true,
            onPass: { complete(diagnosticOutcome("lidar", "LiDAR Scanner", .pass)) },
            onFail: { complete(diagnosticOutcome("lidar", "LiDAR Scanner", .fail)) },
            onSkip: { complete(diagnosticOutcome("lidar", "LiDAR Scanner", .skip)) }
        ) {
            Image(systemName: "cube.transparent").font(.system(size: 44)).foregroundStyle(Color.accentColor)
        }
    }
}
#endif
