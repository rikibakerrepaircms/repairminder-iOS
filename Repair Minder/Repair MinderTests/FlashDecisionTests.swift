import Testing
@testable import Repair_Minder

struct FlashDecisionTests {
    @Test func jumpAutoPasses() {
        #expect(FlashDecision.shouldAutoPass(baseline: 100, peak: 130) == true)
        #expect(FlashDecision.shouldAutoPass(baseline: 100, peak: 110) == false)
    }
}
