import Testing
@testable import Repair_Minder

@MainActor final class FakeAccel: AccelProbe {
    var resting = 0.02; var peak = 0.5
    var baseline = 0.01
    private(set) var baselineSampledBeforePeak = false
    private var peakSampled = false
    func sampleBaseline(windowMs: Int, completion: @escaping (Double) -> Void) {
        baselineSampledBeforePeak = !peakSampled
        completion(baseline)
    }
    func samplePeak(windowMs: Int, completion: @escaping (Double, Double) -> Void) {
        peakSampled = true
        completion(resting, peak)
    }
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
    @Test @MainActor func usesPreBuzzBaselineForGate() async {
        let f = FakeAccel()
        f.baseline = 0.02        // true resting
        f.resting = 0.40         // contaminated in-window value (must be ignored)
        f.peak = 0.30            // peak - baseline = 0.28 >= 0.15 → pass; peak - resting = -0.10 → would fail
        let m = VibrationViewModel(probe: f)
        await m.run()
        #expect(f.baselineSampledBeforePeak)
        #expect(m.outcome?.status == .pass)
    }
}
