import Testing
@testable import Repair_Minder

struct BatteryDrainTests {
    @Test func computesPctPerHourAndConfidence() {
        let r = BatteryDrain.compute(startPct: 80, endPct: 78, elapsedS: 600, granularityPct: 5)
        #expect(r.drainPct == 2)
        #expect(r.drainPctPerHour == 12)
        #expect(r.confidence == "low")
    }
    @Test func highConfidenceWhenAboveGranularity() {
        // ≥ 2 granularity steps (12% over 600s) is "high"
        let r = BatteryDrain.compute(startPct: 80, endPct: 68, elapsedS: 600, granularityPct: 5)
        #expect(r.confidence == "high")
    }
    @Test func highConfidenceRequiresTwoGranularitySteps() {
        // one 5% step over 600s: now "low" (was "high" before the fix)
        let oneStep = BatteryDrain.compute(startPct: 80, endPct: 74, elapsedS: 600, granularityPct: 5)
        #expect(oneStep.confidence == "low")
        // a 12% drop (≥ 2 * 5%) is "high"
        let twoSteps = BatteryDrain.compute(startPct: 80, endPct: 68, elapsedS: 600, granularityPct: 5)
        #expect(twoSteps.confidence == "high")
    }
    @Test func zeroElapsedNoDivideByZero() {
        let r = BatteryDrain.compute(startPct: 80, endPct: 75, elapsedS: 0, granularityPct: 5)
        #expect(r.drainPctPerHour == 0)
    }
    @Test func snapshotMappingReadsAllFields() {
        let snap = BatterySnapshot(levelPct: 80, state: "unplugged", thermalState: "nominal", lowPowerMode: false)
        let d = BatteryTestDetails.from(snap)
        #expect(d["level"] == "80%")
        #expect(d["thermal_state"] == "nominal")
        #expect(d["cycle_count"] == "n/a")
    }
}
