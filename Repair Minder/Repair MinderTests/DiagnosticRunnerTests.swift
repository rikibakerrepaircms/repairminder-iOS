// Repair MinderTests/DiagnosticRunnerTests.swift
import Testing
@testable import Repair_Minder

/// Live-submit stub whose `submitResult` always rejects with `409 session_closed` — models a run
/// the Worker closed on inactivity, so the runner should raise `resumePrompt`.
actor ClosingAPI: DiagnosticsAPI {
    func createSession(_ req: CreateSessionRequest) async throws -> DiagnosticSessionResponse {
        DiagnosticSessionResponse(sessionId: String(repeating: "a", count: 32), sessionToken: "tok", expiresAt: nil, companyName: "Shop")
    }
    func submitResult(_ p: DiagnosticResultPayload) async throws {
        throw APIError.httpError(statusCode: 409, message: "session_closed")
    }
    func complete(sessionId: String, token: String) async throws {}
    func resume(sessionId: String, token: String) async throws {}
    func fetchReport(sessionId: String, token: String) async throws -> String { "<html></html>" }
}

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

    @Test func runAutoRunsSelectedAndDropsUnsupported() async {
        let a = FakeTest(id: "a", name: "A", category: .sensors, isSupported: true, result: .pass)
        let b = FakeTest(id: "b", name: "B", category: .sensors, isSupported: true, result: .pass)
        let c = FakeTest(id: "c", name: "C", category: .sensors, isSupported: false, result: .pass)
        let runner = DiagnosticRunner(tests: [a, b, c])
        runner.select(ids: ["a", "c"])              // c is unsupported, b not selected
        await runner.runAuto()
        #expect(runner.outcome(for: "a")?.status == .pass)
        #expect(runner.outcome(for: "c") == nil)             // unsupported -> dropped entirely
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

/// Live (incremental) reporting: a shop-paired run opens its backend session at the START of
/// `runAuto()` (before any result exists), submits each check as it completes, and never
/// auto-completes — completion is exclusively the operator's explicit Submit/Finish tap
/// (exercised at the DiagnosticsService layer in DiagnosticsServiceTests; the runner never
/// calls `finish`/`complete` itself). Uses a test-injected `DiagnosticsAPI` so these never touch
/// the network regardless of ambient `DiagnosticsShopPairing` state.
@MainActor
struct DiagnosticRunnerLiveReportingTests {
    struct FakeTest: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory = .sensors
        let requiresInteraction = false
        let isSupported = true
        let result: TestStatus
        func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: result, details: nil) }
    }

    @Test func opensLiveSessionAtRunStartWhenPairedAndSubmitsEachCheckLive() async throws {
        DiagnosticsShopPairing.unpair()
        DiagnosticsShopPairing.pair("123456")
        defer { DiagnosticsShopPairing.unpair() }

        let api = StubAPI()
        let a = FakeTest(id: "a", name: "A", result: .pass)
        let b = FakeTest(id: "b", name: "B", result: .fail)
        let runner = DiagnosticRunner(tests: [a, b], diagnosticsAPI: api)
        runner.select(ids: ["a", "b"])
        await runner.runAuto()
        await runner.waitForPendingLiveSubmits()

        #expect(runner.liveSession != nil)
        #expect(await api.created == 1)          // begin() — exactly one session for the whole run
        #expect(await api.results.count == 2)    // one live submit per completed check
        #expect(await api.completed == 0)        // runAuto never completes the session
        #expect(await api.lastCreate?.totalTests == 2)   // selected test count, known at run start
    }

    @Test func doesNotOpenLiveSessionForAnUnpairedRun() async throws {
        DiagnosticsShopPairing.unpair()
        let api = StubAPI()
        let runner = DiagnosticRunner(tests: [FakeTest(id: "a", name: "A", result: .pass)], diagnosticsAPI: api)
        runner.select(ids: ["a"])
        await runner.runAuto()
        await runner.waitForPendingLiveSubmits()

        #expect(runner.liveSession == nil)
        #expect(await api.created == 0)
        #expect(await api.results.isEmpty)
    }

    @Test func sessionClosedOnLiveSubmitRaisesResumePrompt() async throws {
        DiagnosticsShopPairing.unpair()
        DiagnosticsShopPairing.pair("123456")
        defer { DiagnosticsShopPairing.unpair() }

        let runner = DiagnosticRunner(tests: [FakeTest(id: "a", name: "A", result: .pass)], diagnosticsAPI: ClosingAPI())
        runner.select(ids: ["a"])
        await runner.runAuto()
        await runner.waitForPendingLiveSubmits()   // let the fire-and-forget live submit run

        #expect(runner.resumePrompt)               // a 409 session_closed raised the Resume prompt
    }

    @Test func retestResubmitsTheSameTestNameLiveWithoutCompleting() async throws {
        DiagnosticsShopPairing.unpair()
        DiagnosticsShopPairing.pair("123456")
        defer { DiagnosticsShopPairing.unpair() }

        let api = StubAPI()
        let x = FakeTest(id: "x", name: "X", result: .fail)
        let runner = DiagnosticRunner(tests: [x], diagnosticsAPI: api)
        runner.select(ids: ["x"])
        await runner.runAuto()
        await runner.waitForPendingLiveSubmits()
        #expect(await api.results.count == 1)

        await runner.retestAuto(x)   // retest re-records -> re-submits live
        await runner.waitForPendingLiveSubmits()

        #expect(await api.results.count == 2)
        #expect(await api.results.map(\.testName) == ["x", "x"])
        #expect(runner.outcome(for: "x")?.status == .fail)   // FakeTest always returns the same status
        #expect(await api.completed == 0)
    }
}
