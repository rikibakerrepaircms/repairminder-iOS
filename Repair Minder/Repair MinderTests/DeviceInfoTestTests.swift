// Repair MinderTests/DeviceInfoTestTests.swift
import Testing
@testable import Repair_Minder

@MainActor
struct DeviceInfoTestTests {
    @Test func deviceInfoProducesDetails() async {
        let t = DeviceInfoTest()
        #expect(t.requiresInteraction == false)
        #expect(t.isSupported == true)
        let o = await t.run()
        #expect(o.status == .pass)
        #expect(o.details?["os_version"] != nil)
        #expect(o.details?["model"] != nil)
    }
}
