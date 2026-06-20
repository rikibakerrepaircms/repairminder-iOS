// Repair MinderTests/HardwareAutoTests.swift
import Testing
@testable import Repair_Minder

struct HardwareAutoTests {
    @Test func storageRunsAutomaticallyAndReportsCapacity() async {
        let o = await StorageTest().run()
        #expect(o.id == "storage")
        #expect(o.status == .pass || o.status == .skip)
        if o.status == .pass { #expect(o.details?["total"] != nil) }
    }

    @Test func batteryRunsAutomatically() async {
        let o = await BatteryTest().run()
        #expect(o.id == "battery")
        #expect(o.status == .pass || o.status == .skip)
    }
}
