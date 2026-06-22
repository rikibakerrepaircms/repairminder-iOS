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

/// Charge result: wired is required; wireless is optional (skip/na never fails the test).
enum ChargeAggregate {
    static func result(wiredPassed: Bool, wireless: String) -> (status: TestStatus, details: [String: String]) {
        (wiredPassed ? .pass : .fail,
         ["wired": wiredPassed ? "pass" : "fail", "wireless": wireless])
    }
}

/// Hardware-buttons result: every testable (non-`na`) row must be detected ("1"). `na` rows (absent
/// hardware — no mute switch, no Camera Control) are excluded and never fail the test.
enum HardwareButtonsAggregate {
    static func result(rows: [String: String]) -> (status: TestStatus, details: [String: String]) {
        let testable = rows.filter { $0.value != "na" }
        let allPass = !testable.isEmpty && testable.values.allSatisfy { $0 == "1" }
        return (allPass ? .pass : .fail, rows)
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

// Charge: two-step test — wired (required) then wireless (optional / skippable).

private enum ChargeStep { case wired, wireless }

private struct ChargeTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var step: ChargeStep = .wired
    @State private var wiredPassed = false
    @State private var wirelessResult: String? = nil   // "pass" / "skip" ; nil = pending
    @State private var sawUnplugged = false
    @State private var state: UIDevice.BatteryState = .unknown
    @State private var observer: NSObjectProtocol?
    @State private var done = false
    /// True when the device was already charging on appear and hasn't been unplugged yet — Step 1
    /// can't tick until a real unplugged→charging edge is seen, so we prompt the tech to unplug first.
    @State private var alreadyCharging = false

    var body: some View {
        TestScaffold(
            title: "Charge",
            instruction: step == .wired
                ? "Step 1 of 2 — make sure the device is unplugged, then connect the WIRED charger. Ticks when charging starts."
                : "Step 2 of 2 — unplug the wired charger, then place the device on a WIRELESS charger. Tap 'Skip wireless' if you don't have one.",
            hints: step == .wired ? ["Plug in the Lightning/USB-C charger"] : ["Place it on a wireless pad — or Skip wireless"],
            onPass: {}, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            VStack(spacing: 16) {
                chargeTile(title: "Wired", icon: "cable.connector", isDone: wiredPassed, active: step == .wired)
                chargeTile(title: "Wireless", icon: "wave.3.right.circle",
                           isDone: wirelessResult == "pass", skipped: wirelessResult == "skip", active: step == .wireless)
                if step == .wired, alreadyCharging, !wiredPassed {
                    Label("Unplug the device first, then reconnect the charger.", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                if step == .wireless, wirelessResult == nil {
                    Button("Skip wireless") { skipWireless() }
                        .buttonStyle(.rmGlass())
                        .accessibilityIdentifier("charge-skip-wireless")
                }
            }
            .onAppear { startMonitoring() }
            .onDisappear { removeObserver() }
        }
    }

    private func chargeTile(title: String, icon: String, isDone: Bool, skipped: Bool = false, active: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : (skipped ? "minus.circle" : icon))
                .font(.title2).foregroundStyle(isDone ? .green : (skipped ? .secondary : (active ? Color.accentColor : .secondary)))
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(isDone ? "Charging detected" : (skipped ? "Skipped" : (active ? "Waiting…" : "Pending")))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if active && !isDone && !skipped { ProgressView() }
        }
        .padding(12).background(Color.platformGray6).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func startMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        state = UIDevice.current.batteryState
        if state == .unplugged { sawUnplugged = true } else { alreadyCharging = true }
        observer = NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { _ in
            state = UIDevice.current.batteryState
            if state == .unplugged { sawUnplugged = true; alreadyCharging = false }
            handleEdge()
        }
    }

    private func handleEdge() {
        guard !done else { return }
        guard ChargeGate.passed(state: batteryStateLabel(state), sawUnplugged: sawUnplugged) else { return }
        switch step {
        case .wired:
            wiredPassed = true
            // Require a fresh unplugged→charging edge for the wireless step.
            sawUnplugged = false
            step = .wireless
        case .wireless:
            wirelessResult = "pass"
            finishOverall()
        }
    }

    private func skipWireless() {
        wirelessResult = "skip"
        finishOverall()
    }

    private func finishOverall() {
        let (status, details) = ChargeAggregate.result(wiredPassed: wiredPassed, wireless: wirelessResult ?? "na")
        finish(status, details)
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

    // Rows: "0" pending, "1" detected, "na" not present on this device.
    @State private var mute = "0"
    @State private var sideLock = "0"
    @State private var cameraControl = "0"
    @State private var muteBaseline: Bool?
    @State private var done = false

    @State private var screenshotObserver: NSObjectProtocol?
    @State private var mutePoll: Timer?
    @State private var muteTimeout: Timer?
    @State private var cameraTimeout: Timer?
    private let muteProbe = MuteSwitchProbe()

    /// Camera Control is only present on iPhone 16-family devices (iOS 18+). Gate the row on real
    /// hardware support so devices without it (e.g. iPhone 15 Pro Max) never get asked for it.
    private var cameraEligible: Bool { CaptureButtonProbe.isAvailable }
    /// Volume + screenshot + mute all resolved — only then do we activate the capture-button probe,
    /// so its AVCaptureEventInteraction can't intercept the volume/screenshot presses above it.
    private var othersResolved: Bool { watcher.up && watcher.down && sideLock != "0" && mute != "0" }

    var body: some View {
        TestScaffold(
            title: "Hardware Buttons",
            instruction: "Press each button as listed — every row ticks automatically. Buttons your device doesn't have are marked n/a.",
            hints: ["Volume Up, then Down · flip the Ring/Silent switch either way (or hold an Action button set to Silent) · Side + Volume Up together for a screenshot · then press Camera Control"],
            onPass: {}, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            VStack(spacing: 12) {
                row("Volume Up", ok: watcher.up ? "1" : "0")
                row("Volume Down", ok: watcher.down ? "1" : "0")
                row("Mute / Action (Silent)", ok: mute)
                row("Side / Lock (screenshot)", ok: sideLock)
                row("Camera Control", ok: cameraControl)
                if cameraEligible, othersResolved, cameraControl == "0" {
                    CaptureButtonProbe { cameraControl = "1"; checkDone() }
                        .frame(width: 0, height: 0)
                        .onAppear { armCameraTimeout() }
                }
            }
            .onAppear { start() }
            .onDisappear { teardown() }
            .onChange(of: watcher.up) { _, _ in checkDone() }
            .onChange(of: watcher.down) { _, _ in checkDone() }
        }
    }

    private func row(_ label: String, ok: String) -> some View {
        HStack {
            Image(systemName: ok == "1" ? "checkmark.circle.fill" : (ok == "na" ? "minus.circle" : "circle"))
                .foregroundStyle(ok == "1" ? .green : .secondary)
            Text(label).font(.subheadline)
            Spacer()
            if ok == "na" { Text("n/a").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(10).background(Color.platformGray6).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func start() {
        watcher.start()
        // Side/Lock via the screenshot combo (Side + Volume Up).
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main) { _ in
            sideLock = "1"; checkDone()
        }
        // Mute: sample a baseline, then poll for a change after the tech flips the switch.
        muteProbe.sampleSilenced { base in muteBaseline = base }
        mutePoll = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            // The timer fires on the main run loop; assume main-actor isolation so the @MainActor
            // probe call is valid synchronously (no behavioural/timing change).
            MainActor.assumeIsolated {
                muteProbe.sampleSilenced { current in
                    if let base = muteBaseline, current != base { mute = "1"; mutePoll?.invalidate(); checkDone() }
                }
            }
        }
        if !cameraEligible { cameraControl = "na"; checkDone() }
        // Mute degrades to n/a if no toggle is seen (no switch / Action button not set to Silent).
        muteTimeout = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
            if mute == "0" { mute = "na" }
            mutePoll?.invalidate()
            checkDone()
        }
    }

    /// Armed when the capture probe is finally hosted; degrades Camera Control to n/a if no press.
    private func armCameraTimeout() {
        cameraTimeout?.invalidate()
        cameraTimeout = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { _ in
            if cameraControl == "0" { cameraControl = "na" }
            checkDone()
        }
    }

    private func checkDone() {
        guard !done else { return }
        let rows = ["volume_up": watcher.up ? "1" : "0",
                    "volume_down": watcher.down ? "1" : "0",
                    "mute": mute, "side_lock": sideLock, "camera_control": cameraControl]
        guard !rows.values.contains("0") else { return }   // a still-pending row → keep waiting
        let (status, details) = HardwareButtonsAggregate.result(rows: rows)
        finish(status, details)
    }

    private func teardown() {
        watcher.stop()
        mutePoll?.invalidate(); mutePoll = nil
        muteTimeout?.invalidate(); muteTimeout = nil
        cameraTimeout?.invalidate(); cameraTimeout = nil
        if let obs = screenshotObserver { NotificationCenter.default.removeObserver(obs); screenshotObserver = nil }
    }

    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) {
        guard !done else { return }
        done = true
        teardown()
        complete(diagnosticOutcome("hardwarebutton", "Hardware Buttons", s, d))
    }
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
    @Published var waitingForStill = false
    private var hapticEngine: CHHapticEngine?
    private let log = Logger(subsystem: "com.repairminder.diagnostics", category: "vibration")
    init(probe: AccelProbe) { self.probe = probe }

    func run() async {
        // Wait for the device to be laid flat & still so the buzz spike is detectable.
        // Up to ~10s ceiling (12 iterations × ≈400ms sample + 500ms sleep). Bails on cancellation
        // (view dismissed) so a backed-out test doesn't keep sampling motion.
        waitingForStill = true
        for _ in 0..<12 {
            guard !Task.isCancelled else { break }
            let resting = await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
                probe.sampleBaseline(windowMs: 400) { cont.resume(returning: $0) }
            }
            if StillnessGate.isStill(resting: resting) { break }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        waitingForStill = false
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
            let spiked = VibrationGate.spiked(restingNoise: baseline, peak: peakVal, minDelta: 0.08)
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
            instruction: "Lay the device flat on a hard surface and keep still. It pulses for ~2 seconds and auto-detects the motor. If you feel it buzz but it isn’t detected, tap Pass.",
            hints: ["Place it flat on a hard surface (not a soft hand/lap)", "If you feel the buzz, you can Pass it manually"],
            // Auto-detection can miss on devices where a continuous Taptic pulse doesn't register
            // strongly on the accelerometer, so allow a tech to confirm the buzz by feel.
            allowManualPass: true,
            onPass: { complete(diagnosticOutcome("vibration", "Vibration", .pass, ["confirmed": "manual"])) },
            onFail: { complete(diagnosticOutcome("vibration", "Vibration", .fail)) },
            onSkip: { complete(diagnosticOutcome("vibration", "Vibration", .skip)) }
        ) {
            VStack(spacing: 12) {
                Image(systemName: "iphone.radiowaves.left.and.right").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                if model.waitingForStill {
                    ProgressView("Place the device flat and keep still…")
                } else if model.measuring {
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
