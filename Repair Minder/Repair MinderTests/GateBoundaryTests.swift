import Testing
@testable import Repair_Minder

struct GateBoundaryTests {
    // MARK: MotionAliveGate magnitude rails (inclusive 0.7…1.3)
    @Test func accelAlive_atLowerRail_0_7g_passes() {
        #expect(MotionAliveGate.accelerometerAlive(magnitude: 0.7, samples: 5))
    }
    @Test func accelAlive_atUpperRail_1_3g_passes() {
        #expect(MotionAliveGate.accelerometerAlive(magnitude: 1.3, samples: 5))
    }
    @Test func accelAlive_justBelowLowerRail_fails() {
        #expect(!MotionAliveGate.accelerometerAlive(magnitude: 0.699, samples: 5))
    }
    @Test func accelAlive_justAboveUpperRail_fails() {
        #expect(!MotionAliveGate.accelerometerAlive(magnitude: 1.301, samples: 5))
    }
    // MARK: MotionAliveGate sample-count rail (5 is alive, 4 is dead)
    @Test func accelAlive_at5Samples_passes_at4Fails() {
        #expect(MotionAliveGate.accelerometerAlive(magnitude: 1.0, samples: 5))
        #expect(!MotionAliveGate.accelerometerAlive(magnitude: 1.0, samples: 4))
    }
    @Test func gyroAlive_at5Samples_passes_at4Fails() {
        #expect(MotionAliveGate.gyroAlive(samples: 5))
        #expect(!MotionAliveGate.gyroAlive(samples: 4))
    }
    // MARK: VibrationGate at exactly minDelta (inclusive)
    @Test func vibrationGate_atExactlyMinDelta_passes() {
        // peak - resting == 0.15 == minDelta
        #expect(VibrationGate.spiked(restingNoise: 0.05, peak: 0.20, minDelta: 0.15))
    }
    @Test func vibrationGate_justUnderMinDelta_fails() {
        #expect(!VibrationGate.spiked(restingNoise: 0.05, peak: 0.199, minDelta: 0.15))
    }
    // MARK: LoopbackGate at exactly threshold (inclusive)
    @Test func loopbackGate_atExactlyThreshold_heard() {
        #expect(LoopbackGate.heard(levelDb: -20, thresholdDb: -20))
    }
    @Test func loopbackGate_justBelowThreshold_notHeard() {
        #expect(!LoopbackGate.heard(levelDb: -20.1, thresholdDb: -20))
    }
}
