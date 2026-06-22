// Features/Diagnostics/Tests/BatteryDrainTest.swift
// Task 3.9: Honest on-device battery reads + first-class 10-minute drain test.
// Pure maths types (BatteryDrain, BatteryTestDetails) have NO os() guard so they compile on
// the Simulator for unit testing. The interactive view is #if os(iOS) only.
import Foundation
import SwiftUI

// MARK: - Pure maths (unit-tested)

enum BatteryDrain {
    struct Result: Equatable {
        var drainPct: Int
        var drainPctPerHour: Int
        var confidence: String   // "high" | "low"
    }

    /// Compute drain rate.
    /// - Parameters:
    ///   - startPct: Battery % at start of test.
    ///   - endPct: Battery % at end of test.
    ///   - elapsedS: Elapsed seconds.
    ///   - granularityPct: Minimum drop to claim "high" confidence.
    ///     (UIDevice.batteryLevel is reported in 5 % steps on real devices, so a 1–4 % drop
    ///     could just be rounding; drop > granularity means we crossed at least one quantisation
    ///     boundary and are more confident.)
    static func compute(startPct: Int, endPct: Int, elapsedS: Int, granularityPct: Int) -> Result {
        let drop = max(0, startPct - endPct)
        let perHour = elapsedS > 0
            ? Int((Double(drop) / Double(elapsedS)) * 3600.0)
            : 0
        return Result(
            drainPct: drop,
            drainPctPerHour: perHour,
            confidence: drop >= granularityPct * 2 ? "high" : "low"
        )
    }
}

// MARK: - Snapshot → details dict (unit-tested)

enum BatteryTestDetails {
    /// Map a BatterySnapshot to the canonical details dict used by both BatteryTest (auto) and
    /// BatteryDrainTest (interactive). Bridge (USB host-side) fields that can't be read on-device
    /// are explicitly marked "n/a" so the schema is always complete.
    static func from(_ s: BatterySnapshot) -> [String: String] {
        [
            "level":            s.levelPct >= 0 ? "\(s.levelPct)%" : "n/a",
            "state":            s.state,
            "thermal_state":    s.thermalState,
            "low_power_mode":   s.lowPowerMode ? "1" : "0",
            // Bridge-readable fields (not available on-device):
            "cycle_count":      "n/a",
            "health_percent":   "n/a",
            "temperature_c":    "n/a",
            "voltage_mv":       "n/a",
            "max_capacity_mah": "n/a",
        ]
    }
}

// MARK: - DiagnosticTest conformance

#if os(iOS)
struct BatteryDrainTest: DiagnosticTest {
    let id = "battery_drain"
    let name = "Battery Drain"
    let category: TestCategory = .hardware
    let requiresInteraction = true
    var isSupported: Bool { true }

    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? {
        AnyView(BatteryDrainTestView(complete: complete))
    }
}
#else
struct BatteryDrainTest: DiagnosticTest {
    let id = "battery_drain"
    let name = "Battery Drain"
    let category: TestCategory = .hardware
    let requiresInteraction = true
    var isSupported: Bool { false }
}
#endif

// MARK: - Interactive 10-minute drain view (iOS only)

#if os(iOS)
import UIKit

private struct BatteryDrainTestView: View {
    let complete: (TestOutcome) -> Void

    // Duration of the full test (seconds)
    private let targetDurationS = 600

    @State private var startPct: Int = -1
    @State private var currentPct: Int = -1
    @State private var elapsedS: Int = 0
    @State private var running = false
    @State private var timer: Timer? = nil
    @State private var completed = false   // guard: complete() must fire exactly once

    /// Set when a pre-condition (charger unplugged, ≥40 %) isn't met. Drives a visible explanation
    /// instead of the test silently skipping itself and advancing — the tech needs to know *why*.
    /// `reasonCode` is recorded in the outcome details if they choose to Skip from here.
    @State private var blockMessage: String? = nil
    @State private var blockReasonCode: String = ""
    @State private var chargerReconnected = false

    var body: some View {
        TestScaffold(
            title: "Battery Drain",
            instruction: "Unplug the charger, then let the test run for up to 10 minutes. The app samples the battery level every 30 seconds. Tap Stop & Record to end early.",
            hints: [
                "Charger must be disconnected",
                "Battery must be at 40 % or above",
                "Keep the screen on during the test"
            ],
            allowManualPass: false,
            onPass: {},
            onFail: { finishOnce(outcome(status: .fail)) },
            onSkip: {
                // If we're blocked on a pre-condition, carry that reason into the report so the
                // skip is self-explanatory (e.g. "battery_below_40") rather than a bare skip.
                if let _ = blockMessage {
                    finishOnce(diagnosticOutcome("battery_drain", "Battery Drain", .skip,
                                                 ["reason": blockReasonCode]))
                } else {
                    finishOnce(outcome(status: .skip))
                }
            }
        ) {
            VStack(spacing: 16) {
                if let message = blockMessage {
                    // Pre-condition not met — explain plainly and let the tech fix it and retry.
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                    Text("Can’t start the drain test")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Check again") {
                        blockMessage = nil
                        checkPreconditionsAndStart()
                    }
                    .buttonStyle(.rmGlassProminent())
                    .padding(.top, 8)
                } else if running {
                    ProgressView(value: Double(elapsedS), total: Double(targetDurationS))
                        .progressViewStyle(.linear)
                        .padding(.horizontal)

                    Text("Elapsed: \(elapsedS / 60)m \(elapsedS % 60)s / 10m")
                        .font(.subheadline)

                    Text("Battery: \(currentPct >= 0 ? "\(currentPct)%" : "—")")
                        .font(.title2.bold())

                    Text("Start: \(startPct >= 0 ? "\(startPct)%" : "—")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Stop & Record Now") {
                        finishOnce(outcome(status: .pass))
                    }
                    .buttonStyle(.rmGlassProminent())
                    .padding(.top, 8)
                } else {
                    // Shown before pre-conditions are validated on appear
                    ProgressView("Checking battery…")
                }
            }
            .onAppear { checkPreconditionsAndStart() }
            .onDisappear { stopTimer() }
        }
    }

    // MARK: Helpers

    private func checkPreconditionsAndStart() {
        let d = UIDevice.current
        d.isBatteryMonitoringEnabled = true
        let snap = BatteryProbeUIKit().snapshot()

        guard snap.state == "unplugged" else {
            currentPct = snap.levelPct
            blockReasonCode = "charger_connected"
            blockMessage = "The charger is still connected. Unplug the device, then tap Check again. "
                + "(Battery drain can only be measured while running on battery.)"
            return
        }
        guard snap.levelPct >= 40 else {
            currentPct = snap.levelPct
            blockReasonCode = "battery_below_40"
            let level = snap.levelPct >= 0 ? "\(snap.levelPct)%" : "an unknown level"
            blockMessage = "Battery is at \(level). This test needs 40% or more. "
                + "Charge the device above 40%, then tap Check again."
            return
        }

        startPct = snap.levelPct
        currentPct = snap.levelPct
        running = true
        startTimer()
    }

    private func startTimer() {
        let t = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                elapsedS = min(elapsedS + 30, targetDurationS)
                let snap = BatteryProbeUIKit().snapshot()
                currentPct = snap.levelPct
                // Re-check charger state each tick: a mid-run reconnect makes the drain figure
                // meaningless and would otherwise mask a bad battery as a healthy pass.
                if snap.state != "unplugged" {
                    chargerReconnected = true
                    finishOnce(diagnosticOutcome("battery_drain", "Battery Drain", .partial,
                                                 partialDetails(reason: "charger_reconnected")))
                    return
                }
                if elapsedS >= targetDurationS {
                    finishOnce(outcome(status: .pass))
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        running = false
    }

    /// Record the outcome exactly once (multiple call sites + a repeating timer can race).
    private func finishOnce(_ o: TestOutcome) {
        guard !completed else { return }
        completed = true
        stopTimer()
        complete(o)
    }

    /// Build the final TestOutcome, merging drain stats with the snapshot details.
    private func outcome(status: TestStatus) -> TestOutcome {
        let snap = BatteryProbeUIKit().snapshot()
        let finalPct = snap.levelPct >= 0 ? snap.levelPct : currentPct
        let drain = BatteryDrain.compute(
            startPct: startPct,
            endPct: finalPct,
            elapsedS: elapsedS,
            granularityPct: 5
        )
        var details = BatteryTestDetails.from(snap)
        details["drain_start"]           = startPct >= 0 ? "\(startPct)%" : "n/a"
        details["drain_end"]             = finalPct >= 0 ? "\(finalPct)%" : "n/a"
        details["drain_elapsed_s"]       = "\(elapsedS)"
        details["drain_percent"]         = "\(drain.drainPct)"
        details["drain_percent_per_hour"] = "~\(drain.drainPctPerHour) (est.)"
        details["drain_confidence"]      = drain.confidence
        return diagnosticOutcome("battery_drain", "Battery Drain", status, details)
    }

    /// Details for an invalidated run (e.g. charger reconnected) — carry what we measured plus the
    /// reason so the report is self-explanatory rather than a bare partial.
    private func partialDetails(reason: String) -> [String: String] {
        let snap = BatteryProbeUIKit().snapshot()
        var details = BatteryTestDetails.from(snap)
        details["reason"] = reason
        details["drain_start"] = startPct >= 0 ? "\(startPct)%" : "n/a"
        details["drain_elapsed_s"] = "\(elapsedS)"
        return details
    }
}
#endif
