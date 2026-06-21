// Features/Diagnostics/Tests/HardwareTests.swift
// Hardware category (part 1): Storage, Battery (auto), Charge, Hardware Buttons, Vibration.
// Cameras / TrueDepth / LiDAR / Biometric live in CameraTests.swift + BiometricTests.swift.
import SwiftUI
import CoreMotion
#if os(iOS)
import CoreHaptics
#endif

// MARK: - Storage (automatic)

struct StorageTest: DiagnosticTest {
    let id = "storage"; let name = "Storage"; let category: TestCategory = .hardware
    let requiresInteraction = false
    var isSupported: Bool { true }
    func run() async -> TestOutcome {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let v = try? url.resourceValues(forKeys: keys),
              let total = v.volumeTotalCapacity else {
            return diagnosticOutcome(id, name, .skip, ["reason": "unavailable"])
        }
        let available = Int(v.volumeAvailableCapacityForImportantUsage ?? 0)
        let used = max(total - available, 0)
        func gb(_ b: Int) -> String { String(format: "%.1f GB", Double(b) / 1_000_000_000) }
        return diagnosticOutcome(id, name, .pass, ["total": gb(total), "free": gb(available), "used": gb(used)])
    }
}

// MARK: - Battery (automatic)

struct BatteryTest: DiagnosticTest {
    let id = "battery"; let name = "Battery"; let category: TestCategory = .hardware
    let requiresInteraction = false
    var isSupported: Bool { true }
    func run() async -> TestOutcome {
        #if os(iOS)
        let snap = await MainActor.run { BatteryProbeUIKit().snapshot() }
        return diagnosticOutcome(id, name, .pass, BatteryTestDetails.from(snap))
        #else
        return diagnosticOutcome(id, name, .skip, ["reason": "unsupported"])
        #endif
    }
}

// MARK: - Charge (auto-detect charging)

struct ChargeTest: DiagnosticTest {
    let id = "charge"; let name = "Charge"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(ChargeTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - Hardware Buttons (auto-detect volume up + down)

struct HardwareButtonsTest: DiagnosticTest {
    let id = "hardwarebutton"; let name = "Hardware Buttons"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(HardwareButtonsTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - Vibration (accelerometer-gated; auto-pass on detected motor spike)

struct VibrationTest: DiagnosticTest {
    let id = "vibration"; let name = "Vibration"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    // iPads have no vibration motor; gate on haptics hardware capability.
    var isSupported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(VibrationTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

#if os(iOS)
import UIKit
import AVFoundation

func batteryStateLabel(_ s: UIDevice.BatteryState) -> String {
    switch s {
    case .charging: return "charging"
    case .full: return "full"
    case .unplugged: return "unplugged"
    default: return "unknown"
    }
}

// Charge: pass when the device starts charging.

private struct ChargeTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var state: UIDevice.BatteryState = .unknown
    @State private var observer: NSObjectProtocol?
    @State private var done = false

    var body: some View {
        TestScaffold(
            title: "Charge",
            instruction: "Connect the device to a wired or wireless charger. It passes automatically when charging is detected.",
            hints: ["Plug in a charger (or place on a wireless pad)"],
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            VStack(spacing: 8) {
                Image(systemName: (state == .charging || state == .full) ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 44)).foregroundStyle((state == .charging || state == .full) ? .green : .secondary)
                Text(batteryStateLabel(state).capitalized).font(.subheadline)
            }
            .onAppear {
                UIDevice.current.isBatteryMonitoringEnabled = true
                state = UIDevice.current.batteryState
                observer = NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { _ in
                    state = UIDevice.current.batteryState
                    if state == .charging || state == .full { finish(.pass, ["state": batteryStateLabel(state), "ac": "n/a", "dock": "n/a", "usb": "n/a", "wireless": "n/a"]) }
                }
            }
            .onDisappear { removeObserver() }
        }
    }
    private func removeObserver() {
        if let obs = observer { NotificationCenter.default.removeObserver(obs); observer = nil }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) {
        guard !done else { return }
        done = true
        removeObserver()
        complete(diagnosticOutcome("charge", "Charge", s, d))
    }
}

// Hardware Buttons: detect volume up + down via AVAudioSession.outputVolume changes.

@MainActor private final class VolumeWatcher: ObservableObject {
    @Published var up = false
    @Published var down = false
    private var last: Float = AVAudioSession.sharedInstance().outputVolume
    private var observation: NSKeyValueObservation?

    func start() {
        try? AVAudioSession.sharedInstance().setActive(true)
        last = AVAudioSession.sharedInstance().outputVolume
        observation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let self, let v = change.newValue else { return }
            Task { @MainActor in
                if v > self.last { self.up = true } else if v < self.last { self.down = true }
                self.last = v
            }
        }
    }
    func stop() { observation?.invalidate(); observation = nil }
}

private struct HardwareButtonsTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var watcher = VolumeWatcher()

    var body: some View {
        TestScaffold(
            title: "Hardware Buttons",
            instruction: "Press Volume Up and Volume Down. Each registers below; both = pass. (Power/Mute can't be read by apps.)",
            hints: ["Press Volume Up, then Volume Down"],
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            HStack(spacing: 24) {
                buttonState("Volume Up", watcher.up)
                buttonState("Volume Down", watcher.down)
            }
            .onAppear { watcher.start() }
            .onChange(of: watcher.down) { _, _ in checkDone() }
            .onChange(of: watcher.up) { _, _ in checkDone() }
        }
    }
    private func buttonState(_ label: String, _ ok: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle").font(.title).foregroundStyle(ok ? .green : .secondary)
            Text(label).font(.caption)
        }
    }
    private func checkDone() { if watcher.up && watcher.down { finish(.pass, ["volume_up": "1", "volume_down": "1", "power": "n/a", "mute": "n/a"]) } }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) { watcher.stop(); complete(diagnosticOutcome("hardwarebutton", "Hardware Buttons", s, d)) }
}

// Vibration: trigger haptics; auto-pass when the accelerometer detects the motor spike.

@MainActor final class VibrationViewModel: ObservableObject {
    private let probe: AccelProbe
    @Published var outcome: TestOutcome?
    @Published var peak: Double = 0
    @Published var measuring = false
    init(probe: AccelProbe) { self.probe = probe }

    func run() async {
        measuring = true
        buzz()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            probe.samplePeak(windowMs: 1500) { resting, peak in
                Task { @MainActor in
                    self.peak = peak
                    let pass = VibrationGate.spiked(restingNoise: resting, peak: peak, minDelta: 0.15)
                    self.outcome = diagnosticOutcome("vibration", "Vibration", pass ? .pass : .fail,
                                                     ["accel_peak_g": String(format: "%.2f", peak)])
                    self.measuring = false
                    cont.resume()
                }
            }
        }
    }

    private func buzz() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

private struct VibrationTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var model = VibrationViewModel(probe: AccelProbeCM())

    var body: some View {
        TestScaffold(
            title: "Vibration",
            instruction: "Hold the device still. It will vibrate and we'll auto-detect the motor via the accelerometer.",
            hints: ["Keep the device resting on a surface or held still"],
            allowManualPass: false,
            onPass: {},
            onFail: { complete(diagnosticOutcome("vibration", "Vibration", .fail)) },
            onSkip: { complete(diagnosticOutcome("vibration", "Vibration", .skip)) }
        ) {
            VStack(spacing: 12) {
                Image(systemName: "iphone.radiowaves.left.and.right").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                if model.measuring { ProgressView("Measuring…") }
                Button("Vibrate again") { Task { await model.run() } }.buttonStyle(.bordered)
            }
            .task { await model.run() }
            .onChange(of: model.outcome?.status) { _, _ in if let o = model.outcome { complete(o) } }
        }
    }
}
#endif
