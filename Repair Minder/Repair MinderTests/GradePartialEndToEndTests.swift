import Testing
@testable import Repair_Minder

@MainActor
struct GradePartialEndToEndTests {
    struct FakeTest: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory = .hardware
        let requiresInteraction = false
        let isSupported = true
        let result: TestStatus
        func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: result, details: nil) }
    }

    @Test func partialOutcomeMakesOverallResultFail() async {
        let ok = FakeTest(id: "ok", name: "OK", result: .pass)
        let partial = FakeTest(id: "drain", name: "Battery Drain", result: .partial)
        let runner = DiagnosticRunner(tests: [ok, partial])
        runner.selectAll()
        await runner.runAuto()
        #expect(runner.grade == .bad)
        #expect(runner.overallResult == "fail")
    }
}
