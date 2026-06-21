// Repair MinderTests/DiagnosticRunnerPreflightTests.swift
import Testing
import SwiftUI
@testable import Repair_Minder

@MainActor
struct DiagnosticRunnerPreflightTests {
    struct PreflightFake: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory = .sensors
        let requiresInteraction = true
        let isSupported = true
        let preflightStatus: TestStatus?   // nil => preflight returns nil (stays interactive)
        func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { nil }
        func preflight() async -> TestOutcome? {
            guard let s = preflightStatus else { return nil }
            return TestOutcome(id: id, name: name, status: s, details: ["source": "preflight"])
        }
    }

    @Test func preflightPassRecordsAndRemovesFromInteractiveQueue() async {
        let a = PreflightFake(id: "accelerometer", name: "Accelerometer", preflightStatus: .pass)
        let b = PreflightFake(id: "b", name: "B", preflightStatus: nil)
        let runner = DiagnosticRunner(tests: [a, b])
        runner.selectAll()
        await runner.runPreflight()
        #expect(runner.outcome(for: "accelerometer")?.status == .pass)
        #expect(runner.preflightResolvedIds.contains("accelerometer"))
        #expect(runner.selectedInteractiveTests.map(\.id) == ["b"])   // a removed, b stays
    }

    @Test func backgroundPassedListsBannerEligiblePasses() async {
        let accel = PreflightFake(id: "accelerometer", name: "Accelerometer", preflightStatus: .pass)
        let runner = DiagnosticRunner(tests: [accel])
        runner.selectAll()
        await runner.runPreflight()
        #expect(runner.backgroundPassed.map(\.id) == ["accelerometer"])
    }

    @Test func preflightRunsOnlyOnce() async {
        let accel = PreflightFake(id: "accelerometer", name: "Accelerometer", preflightStatus: .pass)
        let runner = DiagnosticRunner(tests: [accel])
        runner.selectAll()
        await runner.runPreflight()
        await runner.runPreflight()   // second call is a no-op
        #expect(runner.preflightResolvedIds.count == 1)
    }
}
