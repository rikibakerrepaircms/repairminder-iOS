// Repair MinderTests/ChargeAggregateTests.swift
import Testing
@testable import Repair_Minder

struct ChargeAggregateTests {
    @Test func wiredRequiredWirelessOptional() {
        let skipped = ChargeAggregate.result(wiredPassed: true, wireless: "skip")
        #expect(skipped.status == .pass)
        #expect(skipped.details["wired"] == "pass")
        #expect(skipped.details["wireless"] == "skip")
        #expect(ChargeAggregate.result(wiredPassed: true, wireless: "pass").status == .pass)
        #expect(ChargeAggregate.result(wiredPassed: false, wireless: "pass").status == .fail)
        // Wired failed + wireless skipped → still a fail (wired is required).
        #expect(ChargeAggregate.result(wiredPassed: false, wireless: "skip").status == .fail)
    }
}
