// Repair MinderTests/RunnerPreflightTests.swift
import Testing
@testable import Repair_Minder

private struct SpyPreflightTest: DiagnosticTest {
    let id = "spy"; let name = "Spy"; let category: TestCategory = .connectivity
    let requiresInteraction = true
    var isSupported: Bool { true }
    var requiredPermissions: [DiagnosticPermission] { [.bluetooth] }
    final class Box: @unchecked Sendable { var called = false }
    let box = Box()
    func preflight() async -> TestOutcome? {
        box.called = true
        return diagnosticOutcome("spy", "Spy", .pass)
    }
}

@MainActor struct RunnerPreflightTests {
    @Test func skipsPreflightForDeniedPermission() async {
        let spy = SpyPreflightTest()
        let runner = DiagnosticRunner(tests: [spy])
        runner.select(ids: ["spy"])
        runner.grantedPermissions = [.bluetooth: false]   // denied
        await runner.runPreflight()
        #expect(spy.box.called == false)
        #expect(runner.outcome(for: "spy") == nil)        // not resolved
    }

    @Test func runsPreflightWhenGranted() async {
        let spy = SpyPreflightTest()
        let runner = DiagnosticRunner(tests: [spy])
        runner.select(ids: ["spy"])
        runner.grantedPermissions = [.bluetooth: true]
        await runner.runPreflight()
        #expect(spy.box.called == true)
        #expect(runner.outcome(for: "spy")?.status == .pass)
    }
}
