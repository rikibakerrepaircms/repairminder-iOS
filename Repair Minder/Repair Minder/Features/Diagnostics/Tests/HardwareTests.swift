// Features/Diagnostics/Tests/HardwareTests.swift
// Hardware category (part 1): Storage, Battery (auto), Charge, Hardware Buttons, Vibration.
// Cameras / TrueDepth / LiDAR / Biometric live in CameraTests.swift + BiometricTests.swift.
import SwiftUI
import CoreMotion
import os
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

/// Pure charge-pass decision: require an observed unplugged→charging edge so a device that was
/// already plugged in (or resting at .full) cannot pass without proving the charger engaged.
enum ChargeGate {
    static func passed(state: String, sawUnplugged: Bool) -> Bool {
        sawUnplugged && (state == "charging" || state == "full")
    }
}

#if os(iOS)
import UIKit
import AVFoundation
import AudioToolbox
import MediaPlayer

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
    @State private var sawUnplugged = false

    var body: some View {
        TestScaffold(
            title: "Charge",
            instruction: "Make sure the device is unplugged, then connect a wired or wireless charger. It passes when charging starts.",
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
                if state == .unplugged { sawUnplugged = true }
                observer = NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { _ in
                    state = UIDevice.current.batteryState
                    if state == .unplugged { sawUnplugged = true }
                    if ChargeGate.passed(state: batteryStateLabel(state), sawUnplugged: sawUnplugged) {
                        finish(.pass, ["state": batteryStateLabel(state), "transition": "unplugged_to_charging", "ac": "n/a", "dock": "n/a", "usb": "n/a", "wireless": "n/a"])
                    }
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
    /// Gate: ignore volume changes until the self-induced mid-rail seed has settled.
    /// Setting the slider fires the KVO observer asynchronously, which would otherwise
    /// register a phantom up/down delta before the user presses anything.
    private var armed = false

    func start() {
        try? AVAudioSession.sharedInstance().setActive(true)
        armed = false
        observation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let self, let v = change.newValue else { return }
            Task { @MainActor in
                guard self.armed else { return }
                if v > self.last + 0.001 { self.up = true } else if v < self.last - 0.001 { self.down = true }
                self.last = v
            }
        }
        setSystemVolume(0.5)
    }

    /// Seed the system volume mid-range so both Volume Up and Volume Down have headroom to move
    /// (at 0 a down-press is a no-op; at 1 an up-press is a no-op → false-fail).
    private func setSystemVolume(_ value: Float) {
        let mpVolume = MPVolumeView()
        if let slider = mpVolume.subviews.compactMap({ $0 as? UISlider }).first {
            DispatchQueue.main.async { [weak self] in
                slider.value = value
                // Arm only once the self-induced change has propagated, then seed `last`
                // from the settled volume so deltas are measured from the mid-rail value.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self else { return }
                    self.last = AVAudioSession.sharedInstance().outputVolume
                    self.armed = true
                }
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
            instruction: "Volume has been set to the middle. Press Volume Up, then Volume Down — each registers below; both = pass. (Power/Mute can't be read by apps.)",
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

// Vibration: trigger a sustained 2s haptic pulse; auto-pass when the accelerometer detects the motor spike.

@MainActor final class VibrationViewModel: ObservableObject {
    private let probe: AccelProbe
    @Published var outcome: TestOutcome?
    @Published var peak: Double = 0
    @Published var measuring = false
    /// Last accelerometer reading from a measuring cycle, shown on screen and logged so the
    /// auto-detect threshold (`minDelta`) can be re-tuned against real hardware. On some devices a
    /// continuous Taptic pulse on a resting surface doesn't clear 0.15 g, so auto-detect never fires
    /// and the tech must confirm the buzz by feel via the manual Pass button.
    @Published var lastResting: Double = 0
    @Published var detected = false
    private var hapticEngine: CHHapticEngine?
    private let log = Logger(subsystem: "com.repairminder.diagnostics", category: "vibration")
    init(probe: AccelProbe) { self.probe = probe }

    func run() async {
        measuring = true
        detected = false
        // Genuine pre-buzz resting baseline (motor OFF) — used by the gate so the buzz isn't
        // compared against itself. Sampled once; the per-cycle in-window resting is logged only.
        let baseline = await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            probe.sampleBaseline(windowMs: 400) { cont.resume(returning: $0) }
        }
        let maxCycles = 3
        for cycle in 0..<maxCycles {
            // Insert a 2s OFF gap between cycles (not before the first one)
            if cycle > 0 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            // Fire the sustained vibration
            await buzz()
            // Sample the accelerometer over the 2s ON window
            let (resting, peakVal) = await withCheckedContinuation { (cont: CheckedContinuation<(Double, Double), Never>) in
                probe.samplePeak(windowMs: 2000) { r, p in
                    cont.resume(returning: (r, p))
                }
            }
            self.peak = peakVal
            self.lastResting = baseline
            let spiked = VibrationGate.spiked(restingNoise: baseline, peak: peakVal, minDelta: 0.15)
            // Logged so we can re-tune the 0.15 g threshold against real devices (Console.app /
            // `log stream --predicate 'subsystem == "com.repairminder.diagnostics"'`).
            log.info("cycle \(cycle, privacy: .public) baseline=\(baseline, format: .fixed(precision: 3), privacy: .public)g inWindowResting=\(resting, format: .fixed(precision: 3), privacy: .public)g peak=\(peakVal, format: .fixed(precision: 3), privacy: .public)g spiked=\(spiked, privacy: .public)")
            if spiked {
                self.detected = true
                self.outcome = diagnosticOutcome("vibration", "Vibration", .pass,
                                                 ["accel_peak_g": String(format: "%.2f", peakVal)])
                self.measuring = false
                return
            }
        }
        // No spike detected after all cycles — leave for user to Pass (by feel) / Fail / Skip
        self.measuring = false
    }

    private func buzz() async {
        // Try CoreHaptics sustained continuous vibration (2s)
        do {
            if hapticEngine == nil {
                hapticEngine = try CHHapticEngine()
            }
            guard let engine = hapticEngine else { throw NSError(domain: "Haptics", code: 0) }
            try await engine.start()
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0,
                duration: 2.0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Fall back: fire AudioServices vibrate every 0.5s for 2s
            hapticEngine = nil
            for _ in 0..<4 {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}

private struct VibrationTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var model = VibrationViewModel(probe: AccelProbeCM())

    var body: some View {
        TestScaffold(
            title: "Vibration",
            instruction: "Hold the device still. It pulses for ~2 seconds and tries to auto-detect the motor. If you feel it buzz but it isn’t detected, tap Pass.",
            hints: ["Keep the device resting on a surface or held still", "If you feel the buzz, you can Pass it manually"],
            // Auto-detection can miss on devices where a continuous Taptic pulse doesn't register
            // strongly on the accelerometer, so allow a tech to confirm the buzz by feel.
            allowManualPass: true,
            onPass: { complete(diagnosticOutcome("vibration", "Vibration", .pass, ["confirmed": "manual"])) },
            onFail: { complete(diagnosticOutcome("vibration", "Vibration", .fail)) },
            onSkip: { complete(diagnosticOutcome("vibration", "Vibration", .skip)) }
        ) {
            VStack(spacing: 12) {
                Image(systemName: "iphone.radiowaves.left.and.right").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                if model.measuring {
                    ProgressView("Measuring…")
                } else if !model.detected {
                    Text("No motor spike detected automatically. If you felt it buzz, tap Pass — otherwise Vibrate again or Fail.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                if model.peak > 0 {
                    Text(String(format: "Accel peak %.2f g · resting %.2f g", model.peak, model.lastResting))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Button("Vibrate again") { Task { await model.run() } }.buttonStyle(.bordered)
            }
            .task { await model.run() }
            .onChange(of: model.outcome?.status) { _, _ in if let o = model.outcome { complete(o) } }
        }
    }
}
#endif
