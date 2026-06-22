import Testing
@testable import Repair_Minder

struct LightGateBoundaryTests {
    // Zero / negative baseline must always reject (dead/black sensor read).
    @Test func zeroBaseline_neverPasses() {
        #expect(LightGate.passes(baseline: 0, peak: 130, thresholdPct: 25, minAbsoluteDelta: 5) == false)
    }
    @Test func negativeBaseline_neverPasses() {
        #expect(LightGate.passes(baseline: -10, peak: 130, thresholdPct: 25, minAbsoluteDelta: 5) == false)
    }
    // Relative bar met AND absolute delta met -> pass.
    @Test func relativeAndAbsoluteBothMet_passes() {
        // baseline 100 -> peak 130: +30% relative, +30 absolute
        #expect(LightGate.passes(baseline: 100, peak: 130, thresholdPct: 25, minAbsoluteDelta: 5) == true)
    }
    // Below the trust floor (baselineFloor == 3): rejected before any relative/absolute math.
    // baseline 1 -> peak 1.3: +30% relative but sub-floor baseline -> reject.
    @Test func subFloorBaseline_fails() {
        #expect(LightGate.passes(baseline: 1, peak: 1.3, thresholdPct: 25, minAbsoluteDelta: 5) == false)
    }
    // ABOVE the floor but the absolute delta is too small while relative is huge -> must FAIL.
    // baseline 5 (>= floor 3) -> peak 20: +300% relative but only +15 absolute (< 30) -> reject.
    // This is the case the original plan/review flagged as missing: it proves the absolute-delta
    // guard fires for a *trusted* baseline, not just for sub-floor reads.
    @Test func aboveFloorButAbsoluteTooSmall_fails() {
        #expect(LightGate.passes(baseline: 5, peak: 20, thresholdPct: 25, minAbsoluteDelta: 30) == false)
    }
    // Absolute delta exactly at minAbsoluteDelta (inclusive) with relative met -> pass.
    @Test func absoluteDeltaAtFloor_passes() {
        // baseline 100 -> peak 125: +25% relative (== threshold), +25 absolute (>= 5)
        #expect(LightGate.passes(baseline: 100, peak: 125, thresholdPct: 25, minAbsoluteDelta: 5) == true)
    }
    // Relative just below threshold -> fail regardless of absolute.
    @Test func relativeJustBelowThreshold_fails() {
        #expect(LightGate.passes(baseline: 100, peak: 124, thresholdPct: 25, minAbsoluteDelta: 5) == false)
    }
}
