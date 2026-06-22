import Testing
@testable import Repair_Minder

struct VibrationFusionTests {
    @Test func randomCodeHasBothClasses() {
        var seed = 0.0
        let code = VibrationCode.random(count: 6) { seed += 0.17; return seed.truncatingRemainder(dividingBy: 1.0) }
        #expect(code.slots.filter { $0 }.count >= 2)
        #expect(code.slots.filter { !$0 }.count >= 2)
    }
    @Test func scoreHighWhenEnergyMatchesCode() {
        let code = VibrationCode(slots: [true, false, true, false], slotS: 0.3)
        let energies = [1.0, 0.05, 1.1, 0.04]   // ON high, OFF low
        #expect(VibrationFusion.score(slotEnergies: energies, code: code) > 5)
    }
    @Test func scoreLowForFlatNoise() {
        let code = VibrationCode(slots: [true, false, true, false], slotS: 0.3)
        let energies = [0.5, 0.5, 0.5, 0.5]     // uniform noise → no correlation
        #expect(VibrationFusion.score(slotEnergies: energies, code: code) < 0.2)
    }
    @Test func slotBucketing() {
        let s = VibrationFusion.slotEnergies(samples: [(0.1, 2), (0.2, 4), (0.4, 10)], slotS: 0.3, slotCount: 2)
        #expect(s[0] == 3)   // (2+4)/2 in slot 0 (0–0.3)
        #expect(s[1] == 10)  // slot 1 (0.3–0.6)
    }
    @Test func fusionRequiresBothChannels() {
        #expect(VibrationFusion.passes(micScore: 2.0, magScore: 0.5))
        #expect(!VibrationFusion.passes(micScore: 2.0, magScore: 0.1))   // mag fails → no pass
        #expect(!VibrationFusion.passes(micScore: 0.3, magScore: 0.5))   // mic fails → no pass
    }
}
