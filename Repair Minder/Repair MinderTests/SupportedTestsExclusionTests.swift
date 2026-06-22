import Testing
@testable import Repair_Minder

@MainActor
struct SupportedTestsExclusionTests {
    struct FakeTest: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory = .sensors
        let requiresInteraction = false
        let isSupported: Bool
        let result: TestStatus
        func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: result, details: nil) }
    }

    @Test func selectAllExcludesUnsupported() {
        let a = FakeTest(id: "a", name: "A", isSupported: true, result: .pass)
        let dead = FakeTest(id: "dead", name: "Dead", isSupported: false, result: .pass)
        let runner = DiagnosticRunner(tests: [a, dead])
        runner.selectAll()
        #expect(runner.isSelected("a"))
        #expect(!runner.isSelected("dead"))   // unsupported never selected
    }

    @Test func unsupportedAbsentFromGradeAndOrderedOutcomes() async {
        let pass = FakeTest(id: "p", name: "P", isSupported: true, result: .pass)
        let dead = FakeTest(id: "dead", name: "Dead", isSupported: false, result: .pass)
        let runner = DiagnosticRunner(tests: [pass, dead])
        runner.selectAll()                     // selects only "p"
        await runner.runAuto()
        // Only the supported test contributes an ordered outcome.
        #expect(runner.orderedOutcomes.map(\.id) == ["p"])
        // All-supported-pass -> excellent (a stray unsupported .skip would have made it .good).
        #expect(runner.grade == .excellent)
        #expect(runner.outcome(for: "dead") == nil)
    }

    @Test func registrySupportedTestsFiltersUnsupported() {
        let supported = TestRegistry.supportedTests()
        #expect(supported.allSatisfy { $0.isSupported })
        // Sanity: supported is a subset of allTests by id.
        let allIds = Set(TestRegistry.allTests().map(\.id))
        #expect(Set(supported.map(\.id)).isSubset(of: allIds))
    }
}
