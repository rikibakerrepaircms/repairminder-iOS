// Repair MinderTests/DiagnosticsServiceTests.swift
import Testing
@testable import Repair_Minder

actor StubAPI: DiagnosticsAPI {
    private(set) var created = 0
    private(set) var results: [DiagnosticResultPayload] = []
    private(set) var completed = 0

    func createSession(_ req: CreateSessionRequest) async throws -> DiagnosticSessionResponse {
        created += 1
        return DiagnosticSessionResponse(sessionId: "sid", sessionToken: "tok", expiresAt: nil)
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
        try await svc.transmit(shopCode: "123456", platform: "ios", imei: "350069708103628",
                               serial: nil, deviceDescription: "iPhone", outcomes: outcomes)
        #expect(await api.created == 1)
        #expect(await api.results.count == 2)
        #expect(await api.completed == 1)
        #expect(await api.results.first?.token == "tok")
    }
}
