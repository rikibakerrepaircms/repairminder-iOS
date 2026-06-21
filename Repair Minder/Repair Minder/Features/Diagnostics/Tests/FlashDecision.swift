// Features/Diagnostics/Tests/FlashDecision.swift
// Pure decision unit: wraps LightGate for the flash luminance test.
// Lives outside #if os(iOS) so unit tests compile on the simulator.
import Foundation

enum FlashDecision {
    static func shouldAutoPass(baseline: Double, peak: Double) -> Bool {
        LightGate.passes(baseline: baseline, peak: peak, thresholdPct: 25, minAbsoluteDelta: 30)
    }
}
