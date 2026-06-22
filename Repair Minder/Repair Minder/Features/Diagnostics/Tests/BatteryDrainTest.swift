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
    @State private var showEndConfirmation = false

    /// Set when a pre-condition (charger unplugged, ≥40 %) isn't met. Drives a visible explanation
    /// instead of the test silently skipping itself and advancing — the tech needs to know *why*.
    /// `reasonCode` is recorded in the outcome details if they choose to Skip from here.
    @State private var blockMessage: String? = nil
    @State private var blockReasonCode: String = ""
    @State private var chargerReconnected = false

    private var secondsRemaining: Int {
        max(0, targetDurationS - elapsedS)
    }

    var body: some View {
        TestScaffold(
            title: "Battery Drain",
            instruction: "Unplug the charger, then let the test run for 10 minutes. The app samples the battery every 30 seconds. Tap \"End test\" if you need to stop early.",
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
            ZStack {
                if let message = blockMessage {
                    // Pre-condition not met — explain plainly and let the tech fix it and retry.
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                        Text("Can't start the drain test")
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
                    }
                } else if running {
                    // Main running layout: clock in centre, battery info below, cat/mouse behind
                    VStack(spacing: 0) {
                        Spacer()

                        // Split-flap countdown clock
                        VStack(spacing: 8) {
                            Text("TIME REMAINING")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .tracking(2)

                            SplitFlapClock(secondsRemaining: secondsRemaining)
                                .padding(.vertical, 8)
                        }

                        Spacer().frame(height: 28)

                        // Battery readings
                        HStack(spacing: 28) {
                            VStack(spacing: 2) {
                                Text(startPct >= 0 ? "\(startPct)%" : "—")
                                    .font(.title3.monospacedDigit().bold())
                                Text("Start")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Divider().frame(height: 32)
                            VStack(spacing: 2) {
                                Text(currentPct >= 0 ? "\(currentPct)%" : "—")
                                    .font(.title3.monospacedDigit().bold())
                                Text("Current")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .rmGlassCardBackground(cornerRadius: 14, fallbackFill: Color(.secondarySystemGroupedBackground))

                        Spacer().frame(height: 20)

                        // End test button (destructive, confirmation required)
                        Button("End test") {
                            showEndConfirmation = true
                        }
                        .buttonStyle(.rmGlassProminent(tint: .orange))
                        .padding(.horizontal)

                        Spacer()
                    }

                    // Cat-chasing-mouse easter egg — looping animation, behind the main content
                    CatAndMouseView()
                } else {
                    // Shown before pre-conditions are validated on appear
                    ProgressView("Checking battery…")
                }
            }
            .onAppear { checkPreconditionsAndStart() }
            .onDisappear { stopTimer() }
            .confirmationDialog(
                "End the battery drain test?",
                isPresented: $showEndConfirmation,
                titleVisibility: .visible
            ) {
                Button("End test", role: .destructive) {
                    let snap = BatteryProbeUIKit().snapshot()
                    var details = BatteryTestDetails.from(snap)
                    details["reason"] = "ended_early"
                    finishOnce(diagnosticOutcome("battery_drain", "Battery Drain", .skip, details))
                }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("It will be recorded as skipped — no drain result.")
            }
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
        // 1-second tick drives the countdown display; battery is re-sampled every 30s.
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsedS = min(elapsedS + 1, targetDurationS)

                // Sample battery every 30 seconds
                if elapsedS % 30 == 0 {
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
    /// Used for .pass (full 10 min elapsed) and .fail paths.
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
        details["drain_percent_per_hour"] = "\(drain.drainPctPerHour)"
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

// MARK: - Cat chasing mouse easter egg

/// A small looping animation of 🐱 chasing 🐭 around the edges of the available space.
/// Lightweight: uses a TimelineView at 60fps only while the test is running.
private struct CatAndMouseView: View {
    // Duration for one full lap (seconds)
    private let lapDuration: Double = 8.0
    // Cat trails the mouse by this fraction of the lap
    private let catTrail: Double = 0.12

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let mousePhase = (t.truncatingRemainder(dividingBy: lapDuration)) / lapDuration
                let catPhase   = (mousePhase - catTrail).truncatingRemainder(dividingBy: 1.0)
                let adjCatPhase = catPhase < 0 ? catPhase + 1.0 : catPhase

                let mousePos = position(for: mousePhase, in: geo.size)
                let catPos   = position(for: adjCatPhase, in: geo.size)

                ZStack {
                    Text("🐭")
                        .font(.system(size: 22))
                        .opacity(0.55)
                        .position(mousePos)

                    Text("🐱")
                        .font(.system(size: 22))
                        .opacity(0.55)
                        .position(catPos)
                }
            }
        }
        .allowsHitTesting(false)   // transparent to taps
    }

    /// Maps a 0–1 phase to a point tracing the perimeter of `size` (clockwise, starting top-left).
    private func position(for phase: Double, in size: CGSize) -> CGPoint {
        let margin: CGFloat = 20
        let w = size.width  - margin * 2
        let h = size.height - margin * 2
        let perimeter = 2 * (w + h)
        let dist = CGFloat(phase) * perimeter

        // Top edge (left → right)
        if dist < w {
            return CGPoint(x: margin + dist, y: margin)
        }
        // Right edge (top → bottom)
        let d1 = dist - w
        if d1 < h {
            return CGPoint(x: margin + w, y: margin + d1)
        }
        // Bottom edge (right → left)
        let d2 = d1 - h
        if d2 < w {
            return CGPoint(x: margin + w - d2, y: margin + h)
        }
        // Left edge (bottom → top)
        let d3 = d2 - w
        return CGPoint(x: margin, y: margin + h - d3)
    }
}
#endif
