import Testing
@testable import Repair_Minder

struct FlashDecisionTests {
    @Test func jumpAutoPasses() {
        #expect(FlashDecision.shouldAutoPass(baseline: 100, peak: 130) == true)
        #expect(FlashDecision.shouldAutoPass(baseline: 100, peak: 110) == false)
    }
    @Test func realisticBaselineWithAbsoluteJumpPasses() {
        // Baseline ≥ floor, peak clears +30 absolute and ≥25% relative.
        #expect(FlashDecision.shouldAutoPass(baseline: 40, peak: 80) == true)
    }
    @Test func relativeJumpOnTinyBaselineDoesNotPass() {
        // Old behaviour false-passed a dead torch on a near-black AGC-inflated baseline:
        // 100% relative but only +2 absolute → must NOT pass now.
        #expect(FlashDecision.shouldAutoPass(baseline: 2, peak: 4) == false)
    }
    @Test func subFloorBaselineDoesNotPass() {
        // A covered/dead sensor reads ~0; no jump from there counts.
        #expect(FlashDecision.shouldAutoPass(baseline: 0, peak: 255) == false)
        #expect(FlashDecision.shouldAutoPass(baseline: 1, peak: 255) == false)
    }
}
