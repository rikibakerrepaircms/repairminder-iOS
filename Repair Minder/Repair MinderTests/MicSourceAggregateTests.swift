import Testing
@testable import Repair_Minder

struct MicSourceAggregateTests {
    @Test func allPresentSourcesPass() {
        let r = MicSourceAggregate.result(perSource: ["bottom": true, "front": true, "back": false])
        #expect(r.status == .fail); #expect(r.details["back"] == "fail")
    }
    @Test func noNamedSourcesFallsBackToSingle() {
        #expect(MicSourceAggregate.result(perSource: ["default": true]).status == .pass)
    }
}
