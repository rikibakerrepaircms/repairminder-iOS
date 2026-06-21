import Testing
@testable import Repair_Minder

@MainActor final class FakeAccel: AccelProbe {
    var resting = 0.02; var peak = 0.5
    func samplePeak(windowMs: Int, completion: @escaping (Double, Double) -> Void) { completion(resting, peak) }
}

struct VibrationGateTests {
    @Test @MainActor func passesOnSpike() async {
        let m = VibrationViewModel(probe: FakeAccel())
        await m.run()
        #expect(m.outcome?.status == .pass)
        #expect(m.outcome?.details?["accel_peak_g"] == "0.50")
    }
    @Test @MainActor func failsWithoutSpike() async {
        let f = FakeAccel(); f.peak = 0.05
        let m = VibrationViewModel(probe: f)
        await m.run()
        #expect(m.outcome?.status != .pass)
    }
}
