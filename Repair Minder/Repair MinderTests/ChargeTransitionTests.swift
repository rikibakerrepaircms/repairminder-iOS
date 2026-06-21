// Repair MinderTests/ChargeTransitionTests.swift
import Testing
@testable import Repair_Minder

struct ChargeTransitionTests {
    @Test func passesOnlyAfterSeenUnpluggedThenCharging() {
        var sawUnplugged = false
        // started plugged in -> must not pass without first seeing unplugged
        #expect(!ChargeGate.passed(state: "charging", sawUnplugged: sawUnplugged))
        #expect(!ChargeGate.passed(state: "full", sawUnplugged: sawUnplugged))
        sawUnplugged = true
        #expect(ChargeGate.passed(state: "charging", sawUnplugged: sawUnplugged))
        #expect(ChargeGate.passed(state: "full", sawUnplugged: sawUnplugged))
        #expect(!ChargeGate.passed(state: "unplugged", sawUnplugged: sawUnplugged))
    }
}
