import Testing
@testable import Repair_Minder

// Note: FakeAccel / AccelProbe-based VibrationViewModel tests are superseded by the
// mic+magnetometer fusion implementation. Pure gate logic is still covered by
// GateBoundaryTests (VibrationGate.spiked), ProbeContractTests, and VibrationFusionTests.
// This file retains a minimal smoke test that the fusion ViewModel initialises cleanly.

@MainActor struct VibrationGateTests {
    @Test func vibrationViewModelInitialisesIdle() {
        let vm = VibrationViewModel()
        #expect(vm.phase == .idle)
        #expect(vm.outcome == nil)
        #expect(!vm.autoFailed)
    }
}
