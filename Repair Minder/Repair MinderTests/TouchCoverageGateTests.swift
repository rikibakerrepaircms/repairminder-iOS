// Repair MinderTests/TouchCoverageGateTests.swift
import Testing
@testable import Repair_Minder

struct TouchCoverageGateTests {
    @Test func passesAt99Percent() {
        #expect(TouchCoverageGate.passed(touched: 99, total: 100))
        #expect(TouchCoverageGate.passed(touched: 100, total: 100))
    }
    @Test func failsBelow99Percent() {
        #expect(!TouchCoverageGate.passed(touched: 98, total: 100))
    }
    @Test func emptyGridNeverPasses() {
        #expect(!TouchCoverageGate.passed(touched: 0, total: 0))
    }
}
