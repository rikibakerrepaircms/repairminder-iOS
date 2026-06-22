// Repair MinderTests/StillnessGateTests.swift
import Testing
@testable import Repair_Minder

struct StillnessGateTests {
    @Test func stillWhenRestingNoiseLow() {
        #expect(StillnessGate.isStill(resting: 0.0))   // sim/fake path returns 0 → must be still
        #expect(StillnessGate.isStill(resting: 0.02))
        #expect(StillnessGate.isStill(resting: 0.049))
    }
    @Test func notStillWhenMoving() {
        #expect(!StillnessGate.isStill(resting: 0.20))
        #expect(!StillnessGate.isStill(resting: 0.05))   // at the threshold = not still
    }
}
