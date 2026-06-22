// Repair MinderTests/SpeakerOutcomeTests.swift
import Testing
@testable import Repair_Minder

struct SpeakerOutcomeTests {
    @Test func passesOnlyWhenBothRoutesHeard() {
        let both = SpeakerOutcome.result(loudPass: true, earPass: true)
        #expect(both.status == .pass)
        #expect(both.details["loud"] == "pass")
        #expect(both.details["ear"] == "pass")
        #expect(SpeakerOutcome.result(loudPass: true, earPass: false).status == .fail)
        #expect(SpeakerOutcome.result(loudPass: false, earPass: true).status == .fail)
    }
}
