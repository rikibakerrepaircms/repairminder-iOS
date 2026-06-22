// Repair MinderTests/HardwareButtonsAggregateTests.swift
import Testing
@testable import Repair_Minder

struct HardwareButtonsAggregateTests {
    @Test func passesWhenEveryTestableRowDetected() {
        let r = HardwareButtonsAggregate.result(rows: [
            "volume_up": "1", "volume_down": "1", "side_lock": "1",
            "mute": "na", "camera_control": "na",
        ])
        #expect(r.status == .pass)
    }
    @Test func failsIfAnyTestableRowMissing() {
        let r = HardwareButtonsAggregate.result(rows: [
            "volume_up": "1", "volume_down": "0", "side_lock": "1",
            "mute": "na", "camera_control": "na",
        ])
        #expect(r.status == .fail)
    }
    @Test func detailsPassedThrough() {
        let r = HardwareButtonsAggregate.result(rows: ["volume_up": "1"])
        #expect(r.details["volume_up"] == "1")
    }
    @Test func failsWhenAllRowsAreNa() {
        // No testable row → not a vacuous pass (the !testable.isEmpty guard).
        let r = HardwareButtonsAggregate.result(rows: ["mute": "na", "camera_control": "na"])
        #expect(r.status == .fail)
    }
}
