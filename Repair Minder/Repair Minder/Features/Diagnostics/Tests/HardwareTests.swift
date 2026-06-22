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

// MARK: - Vibration (mic + magnetometer coded-pulse fusion; auto-pass when both channels correlate)

struct VibrationTest: DiagnosticTest {
    let id = "vibration"; let name = "Vibration"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    // iPads have no vibration motor; gate on haptics hardware capability.
    var isSupported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }
    var requiredPermissions: [DiagnosticPermission] { [.microphone] }
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
    /// Camera Control hardware presence (iPhone 16 family, iOS 18+). Resolved ONCE in start();
    /// when false the row is hidden entirely (not shown as n/a) — e.g. iPhone 15 Pro Max. Cached in
    /// @State because CaptureButtonProbe.isAvailable builds an AVCaptureSession each call.
    @State private var cameraSupported = false
    private let muteProbe = MuteSwitchProbe()
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
                if cameraSupported {
                    row("Camera Control", ok: cameraControl)
                }
                if cameraSupported, othersResolved, cameraControl == "0" {
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
        // Resolve Camera Control hardware presence once. If absent, the row is omitted entirely
        // (not shown, not in the result) rather than displayed as n/a.
        cameraSupported = CaptureButtonProbe.isAvailable
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
        var rows = ["volume_up": watcher.up ? "1" : "0",
                    "volume_down": watcher.down ? "1" : "0",
                    "mute": mute, "side_lock": sideLock]
        // Only include Camera Control when the device actually has it; otherwise it's absent from
        // both the UI and the recorded result (never "na").
        if cameraSupported { rows["camera_control"] = cameraControl }
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

// Vibration: fire a randomized on/off buzz code and require BOTH microphone band energy AND
// magnetometer deviation to correlate with the code → spoof-resistant auto-detection.

enum VibrationPhase { case idle, running, resolved }

@MainActor final class VibrationViewModel: ObservableObject {
    @Published var phase: VibrationPhase = .idle
    @Published var outcome: TestOutcome?
    @Published var autoFailed = false
    @Published var micScore: Double = 0
    @Published var magScore: Double = 0
    /// True when the most recent cycle was disqualified because the phone was being moved/shaken.
    @Published var moved = false
    private var hapticEngine: CHHapticEngine?
    /// Retained for the lifetime of playback — a local player is released when playCode returns,
    /// which silently stops the haptic before it's felt (the "no vibration at all" bug).
    private var hapticPlayer: CHHapticPatternPlayer?
    private let micProbe = MicBandEnergyProbe()
    private let motionProbe = DeviceMotionProbe()
    private let log = Logger(subsystem: "com.repairminder.diagnostics", category: "vibration")

    func run() async {
        guard phase != .running else { return }
        phase = .running
        autoFailed = false
        outcome = nil

        let startTime = CACurrentMediaTime()
        var micSamples: [(t: Double, v: Double)] = []
        var magSamples: [(t: Double, v: Double)] = []
        var motionSamples: [(t: Double, v: Double)] = []
        micProbe.start(startTime: startTime) { t, v in micSamples.append((t, v)) }
        motionProbe.start(startTime: startTime) { t, magDev, motion in
            magSamples.append((t, magDev))
            motionSamples.append((t, motion))
        }

        // Let the magnetometer baseline settle before the first coded buzz.
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Try up to 10 coded cycles; pass on the first where BOTH channels correlate. Run-to-run
        // sensor variance means a genuine buzz may not register on both channels every cycle, so we
        // retry internally instead of making the tech re-run the test by hand.
        let maxCycles = 10
        var bestMic = -Double.greatestFiniteMagnitude
        var bestMag = -Double.greatestFiniteMagnitude
        // Require TWO matching cycles (each with its own random code) to pass — a single lucky noise
        // alignment can't qualify, but a real motor clears both channels repeatedly.
        let requiredMatches = 2
        var matches = 0
        var passed = false

        for cycle in 0..<maxCycles {
            micSamples.removeAll()
            magSamples.removeAll()
            motionSamples.removeAll()
            let cycleStart = CACurrentMediaTime() - startTime   // elapsed at this cycle's code start

            let code = VibrationCode.random { Double.random(in: 0..<1) }
            await playCode(code, offset: 0)

            let codeDuration = Double(code.slots.count) * code.slotS + 0.2
            try? await Task.sleep(nanoseconds: UInt64(codeDuration * 1_000_000_000))

            let micAligned = micSamples.compactMap { s -> (t: Double, v: Double)? in
                let t = s.t - cycleStart; return t >= 0 ? (t, s.v) : nil
            }
            let magAligned = magSamples.compactMap { s -> (t: Double, v: Double)? in
                let t = s.t - cycleStart; return t >= 0 ? (t, s.v) : nil
            }
            // Gross-motion samples over the cycle → mean user-acceleration = how much the phone moved.
            let motionAligned = motionSamples.compactMap { s -> Double? in
                let t = s.t - cycleStart; return t >= 0 ? s.v : nil
            }
            let motionLevel = motionAligned.isEmpty ? 0 : motionAligned.reduce(0, +) / Double(motionAligned.count)
            let still = VibrationFusion.isStill(motionLevel: motionLevel)

            let micEnergies = VibrationFusion.slotEnergies(samples: micAligned, slotS: code.slotS, slotCount: code.slots.count)
            let magEnergies = VibrationFusion.slotEnergies(samples: magAligned, slotS: code.slotS, slotCount: code.slots.count)
            let mScore = VibrationFusion.score(slotEnergies: micEnergies, code: code)
            let gScore = VibrationFusion.score(slotEnergies: magEnergies, code: code)
            bestMic = max(bestMic, mScore)
            bestMag = max(bestMag, gScore)
            self.micScore = mScore
            self.magScore = gScore
            self.moved = !still
            log.info("vibration cycle=\(cycle, privacy: .public) mic=\(mScore, format: .fixed(precision: 3), privacy: .public) mag=\(gScore, format: .fixed(precision: 3), privacy: .public) motion=\(motionLevel, format: .fixed(precision: 3), privacy: .public) still=\(still, privacy: .public) code=\(code.slots.map { $0 ? "1" : "0" }.joined(), privacy: .public)")

            // A cycle only counts when the phone was STILL (shaking/handling is disqualified — the
            // anti-spoof) AND both channels correlate with the coded buzz.
            if still, VibrationFusion.passes(micScore: mScore, magScore: gScore) {
                matches += 1
                if matches >= requiredMatches {
                    passed = true
                    outcome = diagnosticOutcome("vibration", "Vibration", .pass,
                                                ["verified": "mic+magnetometer",
                                                 "mic_score": String(format: "%.2f", mScore),
                                                 "mag_score": String(format: "%.2f", gScore),
                                                 "motion": String(format: "%.2f", motionLevel),
                                                 "cycles": String(cycle + 1),
                                                 "matches": String(matches)])
                    break
                }
            }
            // Brief OFF gap between cycles so they don't bleed together.
            if cycle < maxCycles - 1 { try? await Task.sleep(nanoseconds: 400_000_000) }
        }

        micProbe.stop()
        motionProbe.stop()

        if !passed {
            self.micScore = bestMic.isFinite ? bestMic : 0
            self.magScore = bestMag.isFinite ? bestMag : 0
            autoFailed = true
        }
        phase = .resolved
    }

    private func playCode(_ code: VibrationCode, offset: Double) async {
        do {
            if hapticEngine == nil {
                let e = try CHHapticEngine()
                // The mic probe holds an active record session; playsHapticsOnly decouples the haptic
                // engine from audio routing so the buzz isn't suppressed. Keep it alive across the run.
                e.playsHapticsOnly = true
                e.isAutoShutdownEnabled = false
                hapticEngine = e
            }
            guard let engine = hapticEngine else { throw NSError(domain: "Haptics", code: 0) }
            try await engine.start()
            var events: [CHHapticEvent] = []
            for (i, on) in code.slots.enumerated() where on {
                let t = Double(i) * code.slotS
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: t,
                    duration: code.slotS
                ))
            }
            guard !events.isEmpty else { return }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            hapticPlayer = player   // retain so playback isn't released mid-buzz
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Fallback: fire AudioServices for each ON slot
            hapticEngine = nil
            for (i, on) in code.slots.enumerated() where on {
                let delay = UInt64(Double(i) * code.slotS * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}

private struct VibrationTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var model = VibrationViewModel()

    var body: some View {
        TestScaffold(
            title: "Vibration",
            instruction: "Lay the device flat on a hard surface. It will vibrate for a few seconds to test the motor.",
            hints: ["Place it flat on a hard surface (not a soft hand or lap)", "Keep still while it vibrates"],
            allowManualPass: model.autoFailed,
            onPass: {
                complete(diagnosticOutcome("vibration", "Vibration", .pass, ["confirmed": "manual"]))
            },
            onFail: { complete(diagnosticOutcome("vibration", "Vibration", .fail)) },
            onSkip: { complete(diagnosticOutcome("vibration", "Vibration", .skip)) }
        ) {
            VStack(spacing: 12) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 44)).foregroundStyle(Color.accentColor)
                switch model.phase {
                case .idle:
                    EmptyView()
                case .running:
                    ProgressView("Checking vibration…")
                    if model.moved {
                        Label("Keep the device flat and still — don’t hold or shake it.",
                              systemImage: "hand.raised.slash")
                            .font(.caption).foregroundStyle(.orange)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                case .resolved:
                    if model.autoFailed {
                        Text("Couldn’t confirm the vibration automatically. If you felt it vibrate, tap Pass; if not, tap Fail.")
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                        Text(String(format: "mic %.2f · mag %.2f", model.micScore, model.magScore))
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                if model.phase == .resolved {
                    Button("Run again") { Task { await model.run() } }.buttonStyle(.bordered)
                }
            }
            .task { await model.run() }
            .onChange(of: model.outcome?.status) { _, _ in
                if let o = model.outcome { complete(o) }
            }
        }
    }
}
#endif
