// Repair MinderTests/DiagnosticReportFetchTests.swift
import Testing
import Foundation
@testable import Repair_Minder

/// Task 2: the server report is fetched (not locally rendered) via a proxy-routed, no-auth
/// endpoint. Task 3: every report path first ensures a real server session exists (anon when
/// the device was never paired to a shop).
struct DiagnosticReportFetchTests {
    @Test func reportEndpointPathAndProxyRouting() {
        let ep = APIEndpoint.diagnosticsReport(sessionId: "abc", token: "tok")
        #expect(ep.path == "/api/diagnostics/session/abc/report?token=tok")
        #expect(ep.requiresAuth == false)
        #expect(ep.isDiagnosticsProxyRouted == true)
    }

    @Test func reportEndpointIsGET() {
        #expect(APIEndpoint.diagnosticsReport(sessionId: "abc", token: "tok").method == .get)
    }

    /// `RawTextRequestURL` (backing `APIClient.requestRawText`) must preserve the embedded
    /// `?token=` as a REAL query component, not a percent-encoded literal in the path —
    /// `URL.appendingPathComponent` alone would corrupt it (regression guard for the fix behind
    /// `requestRawText`).
    @Test func rawTextURLPreservesEmbeddedQueryDirect() {
        let url = RawTextRequestURL.resolve(
            endpoint: .diagnosticsReport(sessionId: "abc", token: "tok"),
            baseURL: URL(string: "https://api.repairminder.com")!,
            proxyBase: URL(string: "https://api.kimrelay.com")!)
        #expect(url?.absoluteString == "https://api.kimrelay.com/w/diagnostics/session/abc/report?token=tok")
        #expect(url?.query == "token=tok")
    }

    @Test func rawTextURLSplitsPathAndQuery() {
        let (path, query) = RawTextRequestURL.split(path: "/api/diagnostics/session/abc/report?token=tok")
        #expect(path == "/api/diagnostics/session/abc/report")
        #expect(query == "token=tok")
    }

    @Test func rawTextURLSplitWithNoQueryIsUnchanged() {
        let (path, query) = RawTextRequestURL.split(path: "/api/diagnostics/session/abc/complete")
        #expect(path == "/api/diagnostics/session/abc/complete")
        #expect(query == nil)
    }
}

/// `DiagnosticRunner.ensureSession()` — Task 3.
@MainActor
struct DiagnosticRunnerEnsureSessionTests {
    struct FakeTest: DiagnosticTest {
        let id: String
        let name: String
        let category: TestCategory = .sensors
        let requiresInteraction = false
        let isSupported = true
        let result: TestStatus
        func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: result, details: nil) }
    }

    @Test func reusesAnAlreadyOpenLiveSession() async throws {
        DiagnosticsShopPairing.unpair()
        let api = StubAPI()
        let runner = DiagnosticRunner(tests: [FakeTest(id: "a", name: "A", result: .pass)], diagnosticsAPI: api)
        runner.select(ids: ["a"])
        await runner.runAuto()   // unpaired -> no live session yet
        let first = try await runner.ensureSession()
        let second = try await runner.ensureSession()
        #expect(first.sessionId == second.sessionId)
        #expect(await api.created == 1)   // only the one create from ensureSession, not a second
    }

    @Test func opensAnAnonymousSessionWhenNeverPaired() async throws {
        DiagnosticsShopPairing.unpair()
        let api = StubAPI()
        let runner = DiagnosticRunner(tests: [FakeTest(id: "a", name: "A", result: .pass)], diagnosticsAPI: api)
        runner.select(ids: ["a"])
        await runner.runAuto()
        _ = try await runner.ensureSession()
        #expect(await api.lastCreate?.shopCode == nil)
        #expect(await api.lastCreate?.pairingToken == nil)
        #expect(runner.liveSession != nil)
    }

    @Test func opensThePairedSessionWhenPaired() async throws {
        DiagnosticsShopPairing.unpair()
        DiagnosticsShopPairing.pair("123456")
        defer { DiagnosticsShopPairing.unpair() }

        let api = StubAPI()
        let runner = DiagnosticRunner(tests: [FakeTest(id: "a", name: "A", result: .pass)], diagnosticsAPI: api)
        runner.select(ids: ["a"])
        _ = try await runner.ensureSession()
        #expect(await api.lastCreate?.shopCode == "123456")
    }
}
