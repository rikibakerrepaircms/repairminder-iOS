import Testing
@testable import Repair_Minder

struct ProbeContractTests {
    @Test func luminanceDeltaPasses() {
        #expect(LightGate.passes(baseline: 100, peak: 130, thresholdPct: 25) == true)
        #expect(LightGate.passes(baseline: 100, peak: 120, thresholdPct: 25) == false)
    }
    @Test func accelSpikePasses() {
        #expect(VibrationGate.spiked(restingNoise: 0.02, peak: 0.5, minDelta: 0.15) == true)
        #expect(VibrationGate.spiked(restingNoise: 0.02, peak: 0.10, minDelta: 0.15) == false)
    }
    @Test func loopbackPasses() {
        #expect(LoopbackGate.heard(levelDb: -12, thresholdDb: -20) == true)
        #expect(LoopbackGate.heard(levelDb: -30, thresholdDb: -20) == false)
    }
}
