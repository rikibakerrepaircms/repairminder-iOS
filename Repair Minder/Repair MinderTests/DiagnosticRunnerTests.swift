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

    @Test func runnerRunsSelectedAndSkipsUnsupported() async {
        let a = FakeTest(id: "a", name: "A", category: .sensors, isSupported: true, result: .pass)
        let b = FakeTest(id: "b", name: "B", category: .sensors, isSupported: true, result: .pass)
        let c = FakeTest(id: "c", name: "C", category: .sensors, isSupported: false, result: .pass)
        let runner = DiagnosticRunner(tests: [a, b, c])
        runner.select(ids: ["a", "c"])               // c is unsupported
        await runner.runSelected()
        #expect(runner.outcomes.map(\.id).sorted() == ["a", "c"])
        #expect(runner.outcomes.first { $0.id == "a" }?.status == .pass)
        #expect(runner.outcomes.first { $0.id == "c" }?.status == .skip)   // unsupported -> skip
    }

    @Test func overallResultReflectsWorstOutcome() async {
        let pass = FakeTest(id: "p", name: "P", category: .power, isSupported: true, result: .pass)
        let fail = FakeTest(id: "f", name: "F", category: .power, isSupported: true, result: .fail)
        let runner = DiagnosticRunner(tests: [pass, fail])
        runner.selectAll()
        await runner.runSelected()
        #expect(runner.overallResult == "fail")
    }

    @Test func overallResultPassWhenAllPass() async {
        let pass = FakeTest(id: "p", name: "P", category: .power, isSupported: true, result: .pass)
        let runner = DiagnosticRunner(tests: [pass])
        runner.selectAll()
        await runner.runSelected()
        #expect(runner.overallResult == "pass")
    }
}
