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
}

struct DiagnosticsServiceTests {
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
