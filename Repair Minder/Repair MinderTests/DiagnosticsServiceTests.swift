// Repair MinderTests/DiagnosticsServiceTests.swift
import Testing
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
