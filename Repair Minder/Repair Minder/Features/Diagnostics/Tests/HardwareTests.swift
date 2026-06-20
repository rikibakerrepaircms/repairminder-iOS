// Features/Diagnostics/Tests/HardwareTests.swift
// M360-parity "Hardware" category (part 1): Storage, Battery (auto), Charge, Hardware Buttons, Vibration.
// Cameras / TrueDepth / LiDAR / Biometric live in CameraTests.swift + BiometricTests.swift.
import SwiftUI

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
        return await MainActor.run {
            let d = UIDevice.current
            d.isBatteryMonitoringEnabled = true
            var details: [String: String] = [:]
            let level = d.batteryLevel
            if level >= 0 { details["level"] = "\(Int(level * 100))%" }
            details["state"] = batteryStateLabel(d.batteryState)
            return diagnosticOutcome(id, name, .pass, details)
        }
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

// MARK: - Vibration (trigger + manual confirm)

struct VibrationTest: DiagnosticTest {
    let id = "vibration"; let name = "Vibration"; let category: TestCategory = .hardware
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
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
                NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { _ in
                    state = UIDevice.current.batteryState
                    if state == .charging || state == .full { finish(.pass, ["state": batteryStateLabel(state)]) }
                }
            }
        }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) {
        NotificationCenter.default.removeObserver(self)
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
    private func checkDone() { if watcher.up && watcher.down { finish(.pass, ["volume_up": "1", "volume_down": "1"]) } }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) { watcher.stop(); complete(diagnosticOutcome("hardwarebutton", "Hardware Buttons", s, d)) }
}

// Vibration: trigger haptics; user confirms they felt it (subjective).

private struct VibrationTestView: View {
    let complete: (TestOutcome) -> Void

    var body: some View {
        TestScaffold(
            title: "Vibration",
            instruction: "The device should vibrate. If you feel it, tap Pass. (Ensure vibration isn't disabled in Settings.)",
            hints: ["Hold the device to feel the vibration"],
            allowManualPass: true,   // whether the user felt it is subjective
            onPass: { complete(diagnosticOutcome("vibration", "Vibration", .pass)) },
            onFail: { complete(diagnosticOutcome("vibration", "Vibration", .fail)) },
            onSkip: { complete(diagnosticOutcome("vibration", "Vibration", .skip)) }
        ) {
            VStack(spacing: 12) {
                Image(systemName: "iphone.radiowaves.left.and.right").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                Button("Vibrate again") { buzz() }
                    .buttonStyle(.bordered)
            }
            .onAppear { buzz() }
        }
    }
    private func buzz() {
        let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
        let impact = UIImpactFeedbackGenerator(style: .heavy); impact.impactOccurred()
    }
}
#endif
