import Testing
@testable import Repair_Minder

@MainActor final class FakeLuma: LuminanceProbe {
    func start(onSample: @escaping (Double) -> Void) {
        for _ in 0..<10 { onSample(100) }   // baseline
        onSample(130)                         // +30% jump
    }
    func stop() {}
}

@MainActor final class FlatLuma: LuminanceProbe {
    func start(onSample: @escaping (Double) -> Void) {
        for _ in 0..<12 { onSample(100) }
    }
    func stop() {}
}

struct LightViewModelTests {
    @Test @MainActor func passesOnLuminanceJump() {
        let m = LightViewModel(probe: FakeLuma())
        m.start()
        #expect(m.outcome?.status == .pass)
        #expect(m.outcome?.details?["delta_pct"] == "30")
    }
    @Test @MainActor func noJumpNoPass() {
        let m = LightViewModel(probe: FlatLuma())
        m.start()
        #expect(m.outcome == nil)
    }
}
