import Testing
@testable import Repair_Minder

struct ForceTouchGateTests {
    @Test func passesAboveHalfOfMax() {
        #expect(ForceTouchGate.firm(force: 3.4, maxPossible: 6.0))   // 0.566 > 0.5
    }
    @Test func failsAtOrBelowHalf() {
        #expect(!ForceTouchGate.firm(force: 3.0, maxPossible: 6.0))  // exactly 0.5
        #expect(!ForceTouchGate.firm(force: 1.0, maxPossible: 6.0))
    }
    @Test func rejectsZeroMaxForce() {
        #expect(!ForceTouchGate.firm(force: 5.0, maxPossible: 0))
    }
}
