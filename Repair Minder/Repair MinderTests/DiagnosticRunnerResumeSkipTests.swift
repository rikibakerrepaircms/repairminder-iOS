// Repair MinderTests/DiagnosticRunnerResumeSkipTests.swift
//
// Regression coverage for the resume defect: resuming a session (DiagnosticRunner.rehydrate
// pre-loads server outcomes into `outcomes`/`selectedIds`, phase = .preparing) must NOT re-run
// completed auto tests and must NOT re-present completed interactive tests to the operator. A
// fresh run (no pre-loaded outcomes) must be completely unaffected — every selected test still
// runs/presents exactly once, in order.
import Testing
import SwiftUI
@testable import Repair_Minder

@MainActor
struct DiagnosticRunnerResumeSkipTests {
    /// Automatic (non-interactive) fake. `run()` always returns `rerunStatus` so a test can prove
    /// whether `runAuto` actually invoked it: if a pre-loaded outcome survives unchanged, the test
    /// was correctly skipped; if it flips to `rerunStatus`, it was (incorrectly) re-run.
    struct FakeAutoTest: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory = .sensors
        let requiresInteraction = false
        let isSupported = true
        let rerunStatus: TestStatus
        func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: rerunStatus, details: nil) }
    }

    /// Interactive fake. `makeView` is never exercised here — these tests drive the runner's
    /// index/outcome bookkeeping directly (the same state `TestRunnerView` manipulates) rather than
    /// going through SwiftUI, mirroring the existing `DiagnosticRunnerPhaseTests` style.
    struct FakeInteractiveTest: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory = .sensors
        let requiresInteraction = true
        let isSupported = true
        func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { nil }
    }

    /// Mimics `TestRunnerView`'s advance-on-completion step: record the outcome (as
    /// `handleOutcome` does) then bump `interactiveIndex` (as the flash-view `.task` does once its
    /// confirmation beat elapses).
    private func completeCurrentInteractiveTest(_ runner: DiagnosticRunner, status: TestStatus = .pass) {
        guard let test = runner.currentInteractiveTest else { return }
        runner.record(TestOutcome(id: test.id, name: test.name, status: status, details: nil))
        runner.interactiveIndex += 1
    }

    // MARK: (a) Fresh run — no pre-loaded outcomes — must still visit every selected interactive
    // test exactly once, in order, with no skips and no infinite loop.

    @Test func freshRunProgressesThroughEveryInteractiveTestExactlyOnce() async {
        let i1 = FakeInteractiveTest(id: "i1", name: "I1")
        let i2 = FakeInteractiveTest(id: "i2", name: "I2")
        let i3 = FakeInteractiveTest(id: "i3", name: "I3")
        let runner = DiagnosticRunner(tests: [i1, i2, i3])
        runner.selectAll()

        var visited: [String] = []
        while let test = runner.currentInteractiveTest {
            visited.append(test.id)
            completeCurrentInteractiveTest(runner)
        }

        #expect(visited == ["i1", "i2", "i3"])   // every test, exactly once, in order
        #expect(runner.allSelectedHaveOutcome)
        #expect(runner.currentInteractiveTest == nil)   // terminates cleanly -> TestRunnerView moves to .finished
    }

    @Test func freshRunAutoTestsAllRun() async {
        let a1 = FakeAutoTest(id: "a1", name: "A1", rerunStatus: .pass)
        let a2 = FakeAutoTest(id: "a2", name: "A2", rerunStatus: .fail)
        let runner = DiagnosticRunner(tests: [a1, a2])
        runner.selectAll()
        await runner.runAuto()
        #expect(runner.outcome(for: "a1")?.status == .pass)
        #expect(runner.outcome(for: "a2")?.status == .fail)
    }

    // MARK: (b) Resume — outcomes pre-loaded the way `rehydrate` does — must skip completed tests
    // on both the auto and interactive paths, and reach completion once everything selected has an
    // outcome.

    @Test func resumeSkipsCompletedAutoTestsWithoutOverwriting() async {
        let a1 = FakeAutoTest(id: "a1", name: "A1", rerunStatus: .fail)   // would flip to .fail if re-run
        let a2 = FakeAutoTest(id: "a2", name: "A2", rerunStatus: .pass)
        let runner = DiagnosticRunner(tests: [a1, a2])
        runner.select(ids: ["a1", "a2"])

        // Simulate rehydrate() pre-loading a1's result from the server.
        runner.record(TestOutcome(id: "a1", name: "A1", status: .pass, details: ["source": "server"]))

        await runner.runAuto()

        #expect(runner.outcome(for: "a1")?.status == .pass)               // untouched — NOT re-run
        #expect(runner.outcome(for: "a1")?.details?["source"] == "server")
        #expect(runner.outcome(for: "a2")?.status == .pass)               // freshly run as normal
    }

    @Test func resumeSkipsCompletedInteractiveTestsAndLandsOnFirstUncompleted() async {
        let i1 = FakeInteractiveTest(id: "i1", name: "I1")
        let i2 = FakeInteractiveTest(id: "i2", name: "I2")
        let i3 = FakeInteractiveTest(id: "i3", name: "I3")
        let runner = DiagnosticRunner(tests: [i1, i2, i3])
        runner.select(ids: ["i1", "i2", "i3"])

        // Simulate rehydrate() pre-loading i1's result from the server. interactiveIndex stays at
        // its default 0 (rehydrate doesn't touch it — the runner is freshly constructed).
        runner.record(TestOutcome(id: "i1", name: "I1", status: .pass, details: nil))

        #expect(runner.currentInteractiveTest?.id == "i2")   // skips the already-completed i1

        var visited: [String] = []
        while let test = runner.currentInteractiveTest {
            visited.append(test.id)
            completeCurrentInteractiveTest(runner)
        }

        #expect(visited == ["i2", "i3"])          // i1 never re-presented; each remaining test once
        #expect(runner.allSelectedHaveOutcome)
        #expect(runner.currentInteractiveTest == nil)   // reaches completion -> TestRunnerView moves to .finished
    }

    @Test func resumeWithNonContiguousCompletedInteractiveTestsSkipsAll() async {
        // Completed tests interleaved with not-yet-completed ones (e.g. a resume mid-queue).
        let i1 = FakeInteractiveTest(id: "i1", name: "I1")
        let i2 = FakeInteractiveTest(id: "i2", name: "I2")
        let i3 = FakeInteractiveTest(id: "i3", name: "I3")
        let i4 = FakeInteractiveTest(id: "i4", name: "I4")
        let runner = DiagnosticRunner(tests: [i1, i2, i3, i4])
        runner.select(ids: ["i1", "i2", "i3", "i4"])

        runner.record(TestOutcome(id: "i1", name: "I1", status: .pass, details: nil))
        runner.record(TestOutcome(id: "i3", name: "I3", status: .fail, details: nil))

        var visited: [String] = []
        while let test = runner.currentInteractiveTest {
            visited.append(test.id)
            completeCurrentInteractiveTest(runner)
        }

        #expect(visited == ["i2", "i4"])   // only the two uncompleted ones, each exactly once
        #expect(runner.allSelectedHaveOutcome)
        #expect(runner.outcome(for: "i1")?.status == .pass)   // originals untouched
        #expect(runner.outcome(for: "i3")?.status == .fail)
    }
}
