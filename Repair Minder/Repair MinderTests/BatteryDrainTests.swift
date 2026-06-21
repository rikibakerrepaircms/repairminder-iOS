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
        let r = BatteryDrain.compute(startPct: 80, endPct: 73, elapsedS: 600, granularityPct: 5)
        #expect(r.confidence == "high")
    }
    @Test func snapshotMappingReadsAllFields() {
        let snap = BatterySnapshot(levelPct: 80, state: "unplugged", thermalState: "nominal", lowPowerMode: false)
        let d = BatteryTestDetails.from(snap)
        #expect(d["level"] == "80%")
        #expect(d["thermal_state"] == "nominal")
        #expect(d["cycle_count"] == "n/a")
    }
}
