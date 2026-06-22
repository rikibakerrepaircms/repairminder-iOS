import Testing
@testable import Repair_Minder

@MainActor
struct DiagnosticRunnerResetTests {
    struct FakeTest: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory = .sensors
        let requiresInteraction = false
        let isSupported = true
        let result: TestStatus
        func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: result, details: nil) }
    }

    @Test func resetClearsOutcomesPhaseIndexAndPreflightGuards() async {
        let a = FakeTest(id: "a", name: "A", result: .pass)
        let runner = DiagnosticRunner(tests: [a])
        runner.selectAll()
        await runner.runAuto()
        await runner.runPreflight()
        runner.phase = .interactive
        runner.interactiveIndex = 3
        #expect(runner.outcome(for: "a") != nil)

        runner.reset()

        #expect(runner.outcome(for: "a") == nil)
        #expect(runner.phase == .permissions)
        #expect(runner.interactiveIndex == 0)
        #expect(runner.preflightResolvedIds.isEmpty)
        #expect(runner.autoRan == false)
    }

    @Test func resetGeneratesNewReportID() {
        let runner = DiagnosticRunner(tests: [FakeTest(id: "a", name: "A", result: .pass)])
        let first = runner.reportID          // lazily generated + cached
        runner.reset()
        let second = runner.reportID         // a fresh run must get a fresh reference
        #expect(second != first)
    }
}
