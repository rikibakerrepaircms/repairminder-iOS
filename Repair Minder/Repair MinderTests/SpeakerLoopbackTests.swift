import Testing
@testable import Repair_Minder

@MainActor final class FakeLoopback: LoopbackProbe {
    var levels: [AudioRoute: Double] = [.speaker: -10, .receiver: -40]
    func run(route: AudioRoute, durationMs: Int, onLevel: @escaping (Double) -> Void) { onLevel(levels[route] ?? -120) }
    func stop() {}
}

struct SpeakerLoopbackTests {
    @Test @MainActor func loudPassesWhenHeard() async {
        let m = SpeakerViewModel(probe: FakeLoopback())
        await m.run()
        #expect(m.outcome?.status == .pass)
        #expect(m.outcome?.details?["loud"] == "pass")
    }
    @Test @MainActor func loudFailFailsTest() async {
        let f = FakeLoopback(); f.levels = [.speaker: -50, .receiver: -50]
        let m = SpeakerViewModel(probe: f)
        await m.run()
        #expect(m.outcome?.status == .fail)
        #expect(m.outcome?.details?["loud"] == "fail")
    }
}
