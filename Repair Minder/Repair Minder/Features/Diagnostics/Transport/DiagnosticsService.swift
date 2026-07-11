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

/// How the UI should react to a failed transmit.
/// - `revokedPairing`: the server rejected our credential (403/404) on a *token* pairing — the
///   device is no longer linked. Unpair + tell the user; do NOT buffer (it can never succeed).
/// - `transient`: connectivity / expiry / server hiccup — buffer for the Bridge to replay.
enum DiagnosticsTransmitOutcome: Equatable {
    case revokedPairing
    case transient

    /// `wasTokenPairing` is true only when the failed call authenticated with a server-issued
    /// pairing token (not a manually-typed shop code — a bad code is the user's typo, not revocation).
    static func classify(_ error: Error, wasTokenPairing: Bool) -> DiagnosticsTransmitOutcome {
        guard wasTokenPairing, let api = error as? APIError else { return .transient }
        switch api {
        case .forbidden, .notFound: return .revokedPairing
        default: return .transient
        }
    }
}

/// Abstraction over the Worker diagnostics endpoints (lets tests stub the network).
protocol DiagnosticsAPI: Sendable {
    func createSession(_ req: CreateSessionRequest) async throws -> DiagnosticSessionResponse
    func submitResult(_ p: DiagnosticResultPayload) async throws
    func complete(sessionId: String, token: String) async throws
    /// Reopen a session the Worker had closed on inactivity, so its results can keep streaming.
    func resume(sessionId: String, token: String) async throws
}

/// True when the worker rejected a result because the session already closed on inactivity —
/// the app should offer Resume vs Start again (not silently reopen). Matches only a
/// `409` whose message carries `session_closed`.
enum DiagnosticsResumeSignal {
    static func isSessionClosed(_ error: Error) -> Bool {
        guard let api = error as? APIError else { return false }
        if case let .httpError(statusCode, message) = api {
            return statusCode == 409 && (message?.contains("session_closed") ?? false)
        }
        return false
    }
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
    func resume(sessionId: String, token: String) async throws {
        guard DiagnosticsSessionID.isValid(sessionId) else {
            throw DiagnosticsError.malformedSessionId(sessionId)
        }
        let _: EmptyResponse = try await APIClient.shared.request(.diagnosticsResume(sessionId: sessionId), body: CompleteBody(token: token))
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
    func resume(sessionId: String, token: String) async throws {}
}
#endif

/// Orchestrates create → submit each → complete. Hybrid C: this is the POST path.
/// If transmit fails for connectivity reasons, callers persist the payloads to the app
/// container (see TransmitView buffering); `flushPending` later replays them through the
/// same create → results → complete path so they never strand `in_progress`.
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
                testName: o.id, status: o.status, details: o.details, resumeCapable: true))
        }
        try await api.complete(sessionId: session.sessionId, token: session.sessionToken)
        return session.companyName
    }

    // MARK: - Live (incremental) reporting
    //
    // Split of `transmit` for the live-diagnostics flow: `begin` opens the session at the START
    // of a run (before any result exists, so the dashboard shows it `in_progress` immediately);
    // `submitOne` posts a single check's result as it completes (or re-completes, on retest —
    // the Worker UPSERTs by (session, test_name)); `finish` fires ONLY on the operator's explicit
    // Submit/Finish tap. `transmit`/`flushPending` above are untouched and remain the batch path
    // used for the offline-buffer replay and for a never-paired (consumer) run.

    /// Create the backend session at the start of a run. Only meaningful once a company can be
    /// resolved (`shopCode` or `pairingToken` set) — callers gate on `DiagnosticsShopPairing.isPaired`
    /// before calling this; a fully-unpaired consumer run stays batch-at-end via `transmit`.
    func begin(shopCode: String?, pairingToken: String? = nil, platform: String,
               imei: String?, serial: String?, deviceDescription: String?,
               reportID: String?, totalTests: Int?, startedAt: String?) async throws -> DiagnosticSessionResponse {
        try await api.createSession(CreateSessionRequest(
            shopCode: shopCode, pairingToken: pairingToken, platform: platform, deviceIdentifier: nil,
            deviceDescription: deviceDescription, imei: imei, serial: serial, reportID: reportID,
            overallResult: nil, totalTests: totalTests, startedAt: startedAt))
    }

    /// Submit one completed check's result against a session already opened with `begin`.
    func submitOne(session: DiagnosticSessionResponse, outcome: TestOutcome) async throws {
        try await api.submitResult(DiagnosticResultPayload(
            sessionId: session.sessionId, token: session.sessionToken,
            testName: outcome.id, status: outcome.status, details: outcome.details, resumeCapable: true))
    }

    /// Reopen a session the Worker had closed on inactivity, so its results can keep streaming.
    func resume(sessionId: String, token: String) async throws {
        try await api.resume(sessionId: sessionId, token: token)
    }

    /// Finalise a live session on explicit Submit/Finish. `/complete` has no field for the final
    /// verdict, so the verdict travels the same way it always has — via `createSession` — which
    /// is idempotent by `report_id`: calling it again for the same (company, report_id) updates
    /// `overall_result` on the existing row instead of creating a duplicate (see
    /// `handlePublicCreateDiagnosticSession`). `outcomes` is the FULL current set (not just
    /// deltas) so this also covers any check whose live `submitOne` failed transiently — the
    /// Worker UPSERTs, so re-sending an already-live result is a cheap no-op.
    @discardableResult
    func finish(session: DiagnosticSessionResponse, shopCode: String?, pairingToken: String? = nil,
                platform: String, reportID: String?, overallResult: String?,
                outcomes: [TestOutcome]) async throws -> String? {
        for o in outcomes {
            try await submitOne(session: session, outcome: o)
        }
        let refreshed = try await api.createSession(CreateSessionRequest(
            shopCode: shopCode, pairingToken: pairingToken, platform: platform, reportID: reportID,
            overallResult: overallResult))
        try await api.complete(sessionId: session.sessionId, token: session.sessionToken)
        return refreshed.companyName
    }

    /// Best-effort replay of any buffered (offline) sessions. Each is re-sent through `transmit`
    /// (create -> results -> complete), so a replayed session is fully completed, never stranded
    /// `in_progress`. Removes the file on success or on a hard-auth failure (revoked token = dead
    /// on arrival); keeps it on transient failure to retry later.
    func flushPending() async {
        for url in DiagnosticsBuffer.pendingURLs() {
            guard let s = DiagnosticsBuffer.load(url) else { DiagnosticsBuffer.remove(url); continue }
            let outcomes = s.results.map {
                TestOutcome(id: $0.testName, name: $0.testName,
                            status: TestStatus(rawValue: $0.status) ?? .skip, details: $0.details)
            }
            do {
                _ = try await transmit(shopCode: s.shopCode, pairingToken: s.pairingToken, platform: s.platform,
                                       imei: s.imei, serial: s.serial, deviceDescription: s.deviceDescription,
                                       reportID: s.reportID, overallResult: s.overallResult, outcomes: outcomes)
                DiagnosticsBuffer.remove(url)
            } catch {
                let wasToken = s.pairingToken != nil && s.shopCode == nil
                if DiagnosticsTransmitOutcome.classify(error, wasTokenPairing: wasToken) == .revokedPairing {
                    DiagnosticsBuffer.remove(url)   // can never succeed; drop it
                }
                // transient -> leave buffered for the next flush
            }
        }
    }
}
