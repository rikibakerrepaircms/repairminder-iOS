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
    // The mic-coded correlation is the gate (magnetometer dropped — it can't sample the 230 Hz
    // carrier). A real buzz scores ~3+; flat noise <0.2; the 1.0 default sits well above noise.
    @Test func micCodedGate() {
        #expect(VibrationFusion.passes(micScore: 3.32))   // real buzz on a hard surface → pass
        #expect(VibrationFusion.passes(micScore: 1.0))    // exactly at threshold → pass
        #expect(!VibrationFusion.passes(micScore: 0.31))  // weak/ambient correlation → no pass
        #expect(!VibrationFusion.passes(micScore: -0.2))  // anti-correlated noise → no pass
    }

    // Stillness veto: a resting phone (buzz ~0.05g) is still; a shaken phone (>0.08g) is not.
    @Test func stillnessVetoRejectsMotion() {
        #expect(VibrationFusion.isStill(motionLevel: 0.02))   // at rest
        #expect(VibrationFusion.isStill(motionLevel: 0.05))   // genuine buzz, phone resting
        #expect(!VibrationFusion.isStill(motionLevel: 0.30))  // shaking/handling → disqualified
        #expect(!VibrationFusion.isStill(motionLevel: 0.08))  // at the threshold → not still
    }
}
