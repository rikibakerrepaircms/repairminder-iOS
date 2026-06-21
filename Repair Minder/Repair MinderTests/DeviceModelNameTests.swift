// Repair MinderTests/DeviceModelNameTests.swift
import Testing
@testable import Repair_Minder

struct DeviceModelNameTests {
    @Test func mapsKnownIdentifiersToMarketingNames() {
        #expect(DeviceModelName.name(for: "iPhone15,2") == "iPhone 14 Pro")
        #expect(DeviceModelName.name(for: "iPhone16,2") == "iPhone 15 Pro Max")
        #expect(DeviceModelName.name(for: "iPhone17,3") == "iPhone 16")
    }

    /// iPhone18,3 is the iPhone 17 (verified via the iOS 26 simulator's
    /// SIMULATOR_MODEL_IDENTIFIER) — it must resolve rather than fall back to generic "iPhone".
    @Test func mapsIPhone17() {
        #expect(DeviceModelName.name(for: "iPhone18,3") == "iPhone 17")
    }

    @Test func unknownIdentifierReturnsNil() {
        #expect(DeviceModelName.name(for: "iPhone99,9") == nil)
        #expect(DeviceModelName.name(for: "") == nil)
    }
}
