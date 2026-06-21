import Testing
@testable import Repair_Minder

struct LightGateTests {
    @Test func passesWhenBothRelativeAndAbsoluteMet() {
        #expect(LightGate.passes(baseline: 40, peak: 80, thresholdPct: 25, minAbsoluteDelta: 30))
    }
    @Test func failsWhenRelativeMetButAbsoluteTooSmall() {
        #expect(!LightGate.passes(baseline: 2, peak: 3, thresholdPct: 25, minAbsoluteDelta: 30))
    }
    @Test func failsWhenAbsoluteMetButRelativeTooSmall() {
        #expect(!LightGate.passes(baseline: 200, peak: 235, thresholdPct: 25, minAbsoluteDelta: 30))
    }
    @Test func rejectsSubFloorBaseline() {
        #expect(!LightGate.passes(baseline: 0, peak: 255, thresholdPct: 25, minAbsoluteDelta: 30))
        #expect(!LightGate.passes(baseline: 1, peak: 255, thresholdPct: 25, minAbsoluteDelta: 30))
    }
}
