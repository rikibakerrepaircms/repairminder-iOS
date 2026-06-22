import Testing
@testable import Repair_Minder

@MainActor
struct DiagnosticRunnerSupportedTests {
    struct FakeTest: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory
        let requiresInteraction = false
        let isSupported: Bool
        let result: TestStatus
        func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: result, details: nil) }
    }

    @Test func runAutoOmitsUnsupportedEntirely() async {
        let a = FakeTest(id: "a", name: "A", category: .sensors, isSupported: true, result: .pass)
        let c = FakeTest(id: "c", name: "C", category: .sensors, isSupported: false, result: .pass)
        let runner = DiagnosticRunner(tests: [a, c])
        runner.select(ids: ["a", "c"])
        await runner.runAuto()
        #expect(runner.outcome(for: "a")?.status == .pass)
        #expect(runner.outcome(for: "c") == nil)
        #expect(runner.orderedOutcomes.count == 1)
        #expect(runner.grade == .excellent)
    }

    @Test func selectAllExcludesUnsupported() {
        let a = FakeTest(id: "a", name: "A", category: .sensors, isSupported: true, result: .pass)
        let c = FakeTest(id: "c", name: "C", category: .sensors, isSupported: false, result: .pass)
        let runner = DiagnosticRunner(tests: [a, c])
        runner.selectAll()
        #expect(runner.isSelected("a"))
        #expect(!runner.isSelected("c"))
    }
}
