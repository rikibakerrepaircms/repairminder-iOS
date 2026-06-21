// Repair MinderTests/MotionAliveGateTests.swift
import Testing
@testable import Repair_Minder

struct MotionAliveGateTests {
    @Test func accelAliveNearGravityWithSamples() {
        #expect(MotionAliveGate.accelerometerAlive(magnitude: 1.0, samples: 10))
    }
    @Test func accelDeadWhenTooFewSamples() {
        #expect(!MotionAliveGate.accelerometerAlive(magnitude: 1.0, samples: 2))
    }
    @Test func accelDeadWhenMagnitudeOffGravity() {
        #expect(!MotionAliveGate.accelerometerAlive(magnitude: 0.2, samples: 10))
        #expect(!MotionAliveGate.accelerometerAlive(magnitude: 2.5, samples: 10))
    }
    @Test func gyroAliveWithEnoughSamples() {
        #expect(MotionAliveGate.gyroAlive(samples: 6))
        #expect(!MotionAliveGate.gyroAlive(samples: 4))
    }
}
