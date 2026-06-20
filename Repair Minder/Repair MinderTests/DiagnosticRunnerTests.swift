// Repair MinderTests/DiagnosticRunnerTests.swift
import Testing
@testable import Repair_Minder

@MainActor
struct DiagnosticRunnerTests {
    struct FakeTest: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory
        let requiresInteraction = false
        let isSupported: Bool
        let result: TestStatus
        func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: result, details: nil) }
    }

    @Test func runAutoRunsSelectedAndSkipsUnsupported() async {
        let a = FakeTest(id: "a", name: "A", category: .sensors, isSupported: true, result: .pass)
        let b = FakeTest(id: "b", name: "B", category: .sensors, isSupported: true, result: .pass)
        let c = FakeTest(id: "c", name: "C", category: .sensors, isSupported: false, result: .pass)
        let runner = DiagnosticRunner(tests: [a, b, c])
        runner.select(ids: ["a", "c"])              // c is unsupported, b not selected
        await runner.runAuto()
        #expect(runner.outcome(for: "a")?.status == .pass)
        #expect(runner.outcome(for: "c")?.status == .skip)   // unsupported -> skip
        #expect(runner.outcome(for: "b") == nil)             // not selected -> no outcome
    }

    @Test func overallResultIsFailIfAnyFail() async {
        let pass = FakeTest(id: "p", name: "P", category: .hardware, isSupported: true, result: .pass)
        let fail = FakeTest(id: "f", name: "F", category: .hardware, isSupported: true, result: .fail)
        let runner = DiagnosticRunner(tests: [pass, fail])
        runner.selectAll()
        await runner.runAuto()
        #expect(runner.overallResult == "fail")
        #expect(runner.failedOrSkipped.count == 1)
        #expect(runner.passed.count == 1)
    }

    @Test func overallResultPassWhenAllPass() async {
        let pass = FakeTest(id: "p", name: "P", category: .hardware, isSupported: true, result: .pass)
        let runner = DiagnosticRunner(tests: [pass])
        runner.selectAll()
        await runner.runAuto()
        #expect(runner.overallResult == "pass")
        #expect(runner.allSelectedHaveOutcome)
    }

    @Test func recordOverwritesByIdForRetest() async {
        let runner = DiagnosticRunner(tests: [FakeTest(id: "x", name: "X", category: .screen, isSupported: true, result: .fail)])
        runner.record(TestOutcome(id: "x", name: "X", status: .fail, details: nil))
        runner.record(TestOutcome(id: "x", name: "X", status: .pass, details: nil))
        #expect(runner.outcome(for: "x")?.status == .pass)
    }
}
