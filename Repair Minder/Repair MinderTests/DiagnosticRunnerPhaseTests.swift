import Testing
import SwiftUI
@testable import Repair_Minder

@MainActor
struct DiagnosticRunnerPhaseTests {
    struct PreflightFake: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory = .sensors
        let requiresInteraction = true
        let isSupported = true
        let preflightStatus: TestStatus?
        func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { nil }
        func preflight() async -> TestOutcome? {
            guard let s = preflightStatus else { return nil }
            return TestOutcome(id: id, name: name, status: s, details: ["source": "preflight"])
        }
    }

    // All interactive tests pass in preflight -> empty interactive queue -> finishable.
    @Test func preflightAllResolved_leavesEmptyInteractiveQueue() async {
        let a = PreflightFake(id: "accelerometer", name: "Accelerometer", preflightStatus: .pass)
        let b = PreflightFake(id: "gyroscope", name: "Gyroscope", preflightStatus: .pass)
        let runner = DiagnosticRunner(tests: [a, b])
        runner.selectAll()
        await runner.runPreflight()
        #expect(runner.selectedInteractiveTests.isEmpty)
        #expect(runner.currentInteractiveTest == nil)   // driver can go straight to .finished
    }

    // interactiveIndex at the end of a non-empty queue returns nil (no out-of-bounds).
    @Test func interactiveIndexAtEnd_returnsNilNotCrash() async {
        let a = PreflightFake(id: "a", name: "A", preflightStatus: nil)  // stays interactive
        let runner = DiagnosticRunner(tests: [a])
        runner.selectAll()
        await runner.runPreflight()
        #expect(runner.selectedInteractiveTests.map(\.id) == ["a"])
        #expect(runner.currentInteractiveTest?.id == "a")   // index 0
        runner.interactiveIndex = 1                          // advanced past the single test
        #expect(runner.currentInteractiveTest == nil)        // terminate, no crash
    }

    // Index beyond the queue (e.g. stale advance after queue shrank) is also safe.
    @Test func interactiveIndexFarPastEnd_returnsNil() async {
        let a = PreflightFake(id: "a", name: "A", preflightStatus: nil)
        let runner = DiagnosticRunner(tests: [a])
        runner.selectAll()
        await runner.runPreflight()
        runner.interactiveIndex = 99
        #expect(runner.currentInteractiveTest == nil)
    }
}
