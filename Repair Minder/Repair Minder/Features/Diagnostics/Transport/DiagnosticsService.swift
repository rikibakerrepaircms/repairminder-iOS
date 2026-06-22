// Features/Diagnostics/Transport/DiagnosticsService.swift
import Foundation

/// The Worker `/api/diagnostics/session/:id/complete` route matches the id against
/// `[a-f0-9]{32}` (see worker index.js). The public session-create handler emits exactly
/// that (randomUUID with dashes stripped). If id generation ever changes, `/complete`
/// would 404 silently after all results were posted — so we validate before calling it.
enum DiagnosticsSessionID {
    static func isValid(_ id: String) -> Bool {
        id.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil
    }
}

enum DiagnosticsError: Error, Equatable {
    case malformedSessionId(String)
}

/// Abstraction over the Worker diagnostics endpoints (lets tests stub the network).
protocol DiagnosticsAPI: Sendable {
    func createSession(_ req: CreateSessionRequest) async throws -> DiagnosticSessionResponse
    func submitResult(_ p: DiagnosticResultPayload) async throws
    func complete(sessionId: String, token: String) async throws
}

/// Live implementation backed by APIClient. Endpoints are the ones shipped + verified
/// in the Worker (Plan 1): /api/public/diagnostics/session, /api/diagnostics/results,
/// /api/diagnostics/session/:id/complete. All snake_case; no JWT (session-token/shop-code).
struct LiveDiagnosticsAPI: DiagnosticsAPI {
    func createSession(_ req: CreateSessionRequest) async throws -> DiagnosticSessionResponse {
        try await APIClient.shared.request(.diagnosticsPublicCreate, body: req)
    }
    func submitResult(_ p: DiagnosticResultPayload) async throws {
        let _: EmptyResponse = try await APIClient.shared.request(.diagnosticsSubmitResult, body: p)
    }
    func complete(sessionId: String, token: String) async throws {
        guard DiagnosticsSessionID.isValid(sessionId) else {
            throw DiagnosticsError.malformedSessionId(sessionId)
        }
        let _: EmptyResponse = try await APIClient.shared.request(.diagnosticsComplete(sessionId: sessionId), body: CompleteBody(token: token))
    }
    private struct CompleteBody: Encodable { let token: String }
}

#if DEBUG
/// UI-test stub: succeeds without touching the network (enabled via launch arg).
struct StubDiagnosticsAPI: DiagnosticsAPI {
    func createSession(_ req: CreateSessionRequest) async throws -> DiagnosticSessionResponse {
        DiagnosticSessionResponse(sessionId: "stub", sessionToken: "stub", expiresAt: nil, companyName: nil)
    }
    func submitResult(_ p: DiagnosticResultPayload) async throws {}
    func complete(sessionId: String, token: String) async throws {}
}
#endif

/// Orchestrates create → submit each → complete. Hybrid C: this is the POST path.
/// If transmit fails for connectivity reasons, callers persist the payloads to the app
/// container so the Bridge can pull them over USB/AFC later (see TransmitView buffering).
struct DiagnosticsService: Sendable {
    let api: DiagnosticsAPI
    init(api: DiagnosticsAPI = LiveDiagnosticsAPI()) { self.api = api }

    /// Returns the shop's company name from the server (for "Welcome back …"), or nil if the
    /// Worker didn't supply one. Never a hard-coded value — always the create-session response.
    @discardableResult
    func transmit(shopCode: String?, pairingToken: String? = nil, platform: String,
                  imei: String?, serial: String?,
                  deviceDescription: String?, reportID: String? = nil,
                  overallResult: String? = nil,
                  outcomes: [TestOutcome]) async throws -> String? {
        let session = try await api.createSession(CreateSessionRequest(
            shopCode: shopCode, pairingToken: pairingToken, platform: platform, deviceIdentifier: nil,
            deviceDescription: deviceDescription, imei: imei, serial: serial, reportID: reportID,
            overallResult: overallResult))
        for o in outcomes {
            try await api.submitResult(DiagnosticResultPayload(
                sessionId: session.sessionId, token: session.sessionToken,
                testName: o.id, status: o.status, details: o.details))
        }
        try await api.complete(sessionId: session.sessionId, token: session.sessionToken)
        return session.companyName
    }
}
