import Testing
@testable import Repair_Minder

@MainActor final class FakeLoopback: LoopbackProbe {
    var levels: [AudioRoute: Double] = [.speaker: -10, .receiver: -30]
    func run(route: AudioRoute, durationMs: Int, onLevel: @escaping (Double) -> Void) { onLevel(levels[route] ?? -120) }
    func stop() {}
}

struct SpeakerLoopbackTests {
    @Test @MainActor func bothPassWhenBothHeard() async {
        let m = SpeakerViewModel(probe: FakeLoopback())
        await m.run()
        #expect(m.outcome?.status == .pass)
        #expect(m.outcome?.details?["loud"] == "pass")
        #expect(m.outcome?.details?["ear"] == "pass")
    }
    @Test @MainActor func failsWhenLoudFails() async {
        let f = FakeLoopback(); f.levels = [.speaker: -50, .receiver: -30]
        let m = SpeakerViewModel(probe: f)
        await m.run()
        #expect(m.outcome?.status == .fail)
        #expect(m.outcome?.details?["loud"] == "fail")
        #expect(m.outcome?.details?["ear"] == "pass")
    }
    @Test @MainActor func failsWhenEarFails() async {
        let f = FakeLoopback(); f.levels = [.speaker: -10, .receiver: -120]
        let m = SpeakerViewModel(probe: f)
        await m.run()
        #expect(m.outcome?.status == .fail)
        #expect(m.outcome?.details?["loud"] == "pass")
        #expect(m.outcome?.details?["ear"] == "fail")
    }
    @Test @MainActor func failsWhenBothFail() async {
        let f = FakeLoopback(); f.levels = [.speaker: -50, .receiver: -50]
        let m = SpeakerViewModel(probe: f)
        await m.run()
        #expect(m.outcome?.status == .fail)
        #expect(m.outcome?.details?["loud"] == "fail")
        #expect(m.outcome?.details?["ear"] == "fail")
    }
}
