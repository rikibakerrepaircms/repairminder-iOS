// Repair MinderTests/DiagnosticsServiceTests.swift
import Testing
import Foundation
@testable import Repair_Minder

actor StubAPI: DiagnosticsAPI {
    private(set) var created = 0
    private(set) var results: [DiagnosticResultPayload] = []
    private(set) var completed = 0
    private(set) var lastReportID: String?
    private(set) var lastCreate: CreateSessionRequest?

    func createSession(_ req: CreateSessionRequest) async throws -> DiagnosticSessionResponse {
        created += 1
        lastReportID = req.reportID
        lastCreate = req
        return DiagnosticSessionResponse(sessionId: "sid", sessionToken: "tok", expiresAt: nil, companyName: "Mendmyi")
    }
    func submitResult(_ p: DiagnosticResultPayload) async throws { results.append(p) }
    func complete(sessionId: String, token: String) async throws { completed += 1 }
    func resume(sessionId: String, token: String) async throws {}
}

struct DiagnosticsServiceTests {
    @Test func resultPayloadEncodesResumeCapableSnakeCase() throws {
        let p = DiagnosticResultPayload(sessionId: "a", token: "t", testName: "wifi", status: .pass, details: nil, resumeCapable: true)
        let enc = JSONEncoder(); enc.keyEncodingStrategy = .convertToSnakeCase
        let json = String(decoding: try enc.encode(p), as: UTF8.self)
        #expect(json.contains("\"resume_capable\":true"))
    }

    @Test func transmitCreatesSessionSubmitsEachResultThenCompletes() async throws {
        let api = StubAPI()
        let svc = DiagnosticsService(api: api)
        let outcomes = [
            TestOutcome(id: "a", name: "A", status: .pass, details: nil),
            TestOutcome(id: "b", name: "B", status: .fail, details: ["x": "y"]),
        ]
        let companyName = try await svc.transmit(shopCode: "123456", platform: "ios", imei: "350069708103628",
                               serial: nil, deviceDescription: "iPhone",
                               reportID: "RM-20260621-1342-7F3A9C", outcomes: outcomes)
        #expect(companyName == "Mendmyi")   // surfaced from the create-session response, not hard-coded
        #expect(await api.created == 1)
        #expect(await api.results.count == 2)
        #expect(await api.completed == 1)
        #expect(await api.results.first?.token == "tok")
        // The report id is logged to us with the session so report ↔ results can be matched.
        #expect(await api.lastReportID == "RM-20260621-1342-7F3A9C")
    }

    @Test func transmitForwardsOverallResultToCreatePayload() async throws {
        let api = StubAPI()
        let svc = DiagnosticsService(api: api)
        _ = try await svc.transmit(shopCode: "123456", platform: "ios", imei: nil, serial: nil,
                                   deviceDescription: "iPhone", reportID: "RM-1",
                                   overallResult: "partial",
                                   outcomes: [TestOutcome(id: "a", name: "A", status: .pass, details: nil)])
        #expect(await api.lastCreate?.overallResult == "partial")
    }
}

struct DiagnosticsLiveServiceTests {
    @Test func beginCreatesSessionWithTotalTestsAndStartedAtBeforeAnyResult() async throws {
        let api = StubAPI()
        let svc = DiagnosticsService(api: api)
        let session = try await svc.begin(shopCode: "123456", platform: "ios", imei: nil, serial: nil,
                                          deviceDescription: "iPhone 15", reportID: "RM-1",
                                          totalTests: 22, startedAt: "2026-07-11T09:00:00Z")
        #expect(session.sessionId == "sid")
        #expect(await api.created == 1)
        #expect(await api.results.isEmpty)     // no result posted yet — begin() precedes every check
        #expect(await api.completed == 0)
        #expect(await api.lastCreate?.totalTests == 22)
        #expect(await api.lastCreate?.startedAt == "2026-07-11T09:00:00Z")
    }

    @Test func submitOnePostsASingleResultAgainstAnOpenSession() async throws {
        let api = StubAPI()
        let svc = DiagnosticsService(api: api)
        let session = DiagnosticSessionResponse(sessionId: "sid", sessionToken: "tok", expiresAt: nil, companyName: nil)
        try await svc.submitOne(session: session, outcome: TestOutcome(id: "a", name: "A", status: .pass, details: nil))
        #expect(await api.results.count == 1)
        #expect(await api.results.first?.testName == "a")
        #expect(await api.completed == 0)   // submitOne never completes
    }

    @Test func retestSubmitsAgainUnderTheSameTestName() async throws {
        let api = StubAPI()
        let svc = DiagnosticsService(api: api)
        let session = DiagnosticSessionResponse(sessionId: "sid", sessionToken: "tok", expiresAt: nil, companyName: nil)
        try await svc.submitOne(session: session, outcome: TestOutcome(id: "a", name: "A", status: .fail, details: nil))
        try await svc.submitOne(session: session, outcome: TestOutcome(id: "a", name: "A", status: .pass, details: nil))
        #expect(await api.results.count == 2)
        #expect(await api.results.map(\.testName) == ["a", "a"])
        #expect(await api.results.last?.status == .pass)
    }

    @Test func finishSubmitsOutcomesRefreshesVerdictThenCompletesOnce() async throws {
        let api = StubAPI()
        let svc = DiagnosticsService(api: api)
        let session = DiagnosticSessionResponse(sessionId: "sid", sessionToken: "tok", expiresAt: nil, companyName: "Mendmyi")
        let companyName = try await svc.finish(
            session: session, shopCode: "123456", platform: "ios", reportID: "RM-1", overallResult: "pass",
            outcomes: [TestOutcome(id: "a", name: "A", status: .pass, details: nil),
                       TestOutcome(id: "b", name: "B", status: .pass, details: nil)])
        #expect(companyName == "Mendmyi")
        #expect(await api.results.count == 2)
        #expect(await api.created == 1)                       // the overall_result-refresh create
        #expect(await api.lastCreate?.overallResult == "pass")
        #expect(await api.completed == 1)                     // completes exactly once
    }
}

struct DiagnosticsBufferTests {
    @Test func bufferedSessionEncodesNeedsCompleteAsSnakeCase() throws {
        let url = DiagnosticsBuffer.save(shopCode: "123456", deviceDescription: "iPhone",
                                         imei: nil, serial: nil, reportID: "RM-1",
                                         outcomes: [TestOutcome(id: "a", name: "A", status: .pass, details: nil)])
        let data = try Data(contentsOf: #require(url))
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"needs_complete\":true"))
        #expect(json.contains("\"report_id\":\"RM-1\""))
        try? FileManager.default.removeItem(at: #require(url))
    }
}

/// Recording stub that can be configured to throw, for flush tests.
actor FlushStubAPI: DiagnosticsAPI {
    enum Failure { case none, transient, forbidden }
    private let failure: Failure
    private(set) var created = 0
    private(set) var results: [DiagnosticResultPayload] = []
    private(set) var completed = 0

    init(failure: Failure = .none) { self.failure = failure }

    func createSession(_ req: CreateSessionRequest) async throws -> DiagnosticSessionResponse {
        switch failure {
        case .none: break
        case .transient: throw APIError.networkError(URLError(.notConnectedToInternet))
        case .forbidden: throw APIError.forbidden(message: "revoked", code: nil)
        }
        created += 1
        return DiagnosticSessionResponse(sessionId: "sid", sessionToken: "tok", expiresAt: nil, companyName: "Mendmyi")
    }
    func submitResult(_ p: DiagnosticResultPayload) async throws { results.append(p) }
    func complete(sessionId: String, token: String) async throws { completed += 1 }
    func resume(sessionId: String, token: String) async throws {}
}

struct DiagnosticsResumeSignalTests {
    @Test func detectsSessionClosed() {
        #expect(DiagnosticsResumeSignal.isSessionClosed(APIError.httpError(statusCode: 409, message: "session_closed")))
        #expect(!DiagnosticsResumeSignal.isSessionClosed(APIError.httpError(statusCode: 410, message: "expired")))
        #expect(!DiagnosticsResumeSignal.isSessionClosed(APIError.httpError(statusCode: 409, message: nil)))
        #expect(!DiagnosticsResumeSignal.isSessionClosed(APIError.notFound))
    }
}

struct DiagnosticsFlushTests {
    /// Remove every buffered file so a test starts and ends with a clean pending directory.
    private func clearPending() {
        for url in DiagnosticsBuffer.pendingURLs() { DiagnosticsBuffer.remove(url) }
    }

    @Test func flushSuccessfullyReplaysAndRemovesFile() async throws {
        clearPending()
        defer { clearPending() }
        let url = try #require(DiagnosticsBuffer.save(
            shopCode: "123456", deviceDescription: "iPhone", imei: nil, serial: nil,
            reportID: "RM-1", overallResult: "pass",
            outcomes: [TestOutcome(id: "a", name: "A", status: .pass, details: nil),
                       TestOutcome(id: "b", name: "B", status: .fail, details: ["x": "y"])]))
        let api = FlushStubAPI(failure: .none)
        await DiagnosticsService(api: api).flushPending()
        // create + N results + complete all happened
        #expect(await api.created == 1)
        #expect(await api.results.count == 2)
        #expect(await api.completed == 1)
        // the file is gone (replayed successfully)
        #expect(!DiagnosticsBuffer.pendingURLs().contains(url))
    }

    @Test func flushKeepsFileOnTransientFailure() async throws {
        clearPending()
        defer { clearPending() }
        let url = try #require(DiagnosticsBuffer.save(
            shopCode: "123456", deviceDescription: "iPhone", imei: nil, serial: nil,
            reportID: "RM-1", overallResult: "pass",
            outcomes: [TestOutcome(id: "a", name: "A", status: .pass, details: nil)]))
        let api = FlushStubAPI(failure: .transient)
        await DiagnosticsService(api: api).flushPending()
        // transient -> file remains buffered for the next flush
        #expect(DiagnosticsBuffer.pendingURLs().contains(url))
    }

    @Test func flushDropsFileOnRevokedTokenPairing() async throws {
        clearPending()
        defer { clearPending() }
        // pairingToken set + shopCode nil => a token pairing; forbidden = revoked = dead on arrival.
        let url = try #require(DiagnosticsBuffer.save(
            shopCode: nil, pairingToken: "tok-123", deviceDescription: "iPhone", imei: nil, serial: nil,
            reportID: "RM-1", overallResult: "pass",
            outcomes: [TestOutcome(id: "a", name: "A", status: .pass, details: nil)]))
        let api = FlushStubAPI(failure: .forbidden)
        await DiagnosticsService(api: api).flushPending()
        // revoked -> file removed (can never succeed)
        #expect(!DiagnosticsBuffer.pendingURLs().contains(url))
    }
}

struct DiagnosticsTransmitErrorTests {
    @Test func forbiddenOnTokenPairingIsHardAuth() {
        let outcome = DiagnosticsTransmitOutcome.classify(
            APIError.forbidden(message: "Pairing not recognised or revoked", code: nil),
            wasTokenPairing: true)
        #expect(outcome == .revokedPairing)
    }
    @Test func notFoundOnTokenPairingIsHardAuth() {
        #expect(DiagnosticsTransmitOutcome.classify(APIError.notFound, wasTokenPairing: true) == .revokedPairing)
    }
    @Test func forbiddenOnShopCodeIsNotRevocation() {
        // A 403/404 on a manually-typed shop code is a bad code, not a revoked device pairing.
        #expect(DiagnosticsTransmitOutcome.classify(APIError.notFound, wasTokenPairing: false) == .transient)
    }
    @Test func networkErrorIsTransient() {
        #expect(DiagnosticsTransmitOutcome.classify(
            APIError.networkError(URLError(.notConnectedToInternet)), wasTokenPairing: true) == .transient)
    }
    @Test func expiredOrServerErrorIsTransient() {
        #expect(DiagnosticsTransmitOutcome.classify(APIError.httpError(statusCode: 410, message: nil), wasTokenPairing: true) == .transient)
        #expect(DiagnosticsTransmitOutcome.classify(APIError.httpError(statusCode: 503, message: nil), wasTokenPairing: true) == .transient)
    }
}
