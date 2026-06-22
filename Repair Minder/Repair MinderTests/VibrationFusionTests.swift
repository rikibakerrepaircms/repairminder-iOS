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
    // Both channels must correlate on the SAME cycle to pass (strong anti-spoof). Cases mirror real
    // device data: only the cycle where mic AND mag both cleared (0.65/0.79) passes.
    @Test func fusionRequiresBothChannels() {
        #expect(VibrationFusion.passes(micScore: 0.65, magScore: 0.79))   // both ≥0.4 → pass
        #expect(!VibrationFusion.passes(micScore: 1.63, magScore: -0.32)) // mag fails → no pass
        #expect(!VibrationFusion.passes(micScore: 0.31, magScore: 1.30))  // mic 0.31<0.4 → no pass
        #expect(!VibrationFusion.passes(micScore: -0.2, magScore: -0.14)) // both fail
    }

    // Stillness veto: a resting phone (buzz ~0.05g) is still; a shaken phone (>0.08g) is not.
    @Test func stillnessVetoRejectsMotion() {
        #expect(VibrationFusion.isStill(motionLevel: 0.02))   // at rest
        #expect(VibrationFusion.isStill(motionLevel: 0.05))   // genuine buzz, phone resting
        #expect(!VibrationFusion.isStill(motionLevel: 0.30))  // shaking/handling → disqualified
        #expect(!VibrationFusion.isStill(motionLevel: 0.08))  // at the threshold → not still
    }
}
