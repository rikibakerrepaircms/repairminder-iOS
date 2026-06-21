// Repair MinderTests/RearCameraAggregateTests.swift
import Testing
@testable import Repair_Minder

struct RearCameraAggregateTests {
    @Test func allPresentLensesMustPass() {
        let r = RearCameraAggregate.result(perLens: ["ultrawide": true, "wide": true, "tele": false])
        #expect(r.status == .fail)
        #expect(r.details["tele"] == "fail")
        #expect(r.details["wide"] == "pass")
    }
    @Test func singleLensDevicePasses() {
        #expect(RearCameraAggregate.result(perLens: ["wide": true]).status == .pass)
    }
    @Test func emptyIsSkip() {
        #expect(RearCameraAggregate.result(perLens: [:]).status == .skip)
    }
}
