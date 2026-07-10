// Features/Diagnostics/Engine/DiagnosticModels.swift
import Foundation

/// Per-test result status (wire value matches Worker: pass|fail|skip|error|partial).
enum TestStatus: String, Codable, Sendable {
    case pass, fail, skip, error, partial

    /// Decode defensively: an unrecognised status from a newer backend maps to `.error`
    /// rather than failing the entire response decode.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TestStatus(rawValue: raw) ?? .error
    }
}

/// Request body for POST /api/public/diagnostics/session (shop-code path).
struct CreateSessionRequest: Codable, Sendable {
    let shopCode: String?
    /// Server-issued pairing credential (preferred over shopCode); sent as `pairing_token`.
    let pairingToken: String?
    let platform: String
    let deviceIdentifier: String?
    let deviceDescription: String?
    let imei: String?
    let serial: String?
    /// Client-generated run reference (also printed on the customer's PDF) so the results we
    /// log can be matched to the report. Sent as `report_id`; ignored by older Workers.
    let reportID: String?
    /// Run verdict ("pass"/"partial"/"fail") computed by the runner; sent as `overall_result`.
    /// Additive — older Workers ignore it.
    let overallResult: String?
    /// Number of checks selected for this run, known at run start; sent as `total_tests` so the
    /// dashboard's live board can render "N of M" before any result exists. Additive/nullable —
    /// older Workers ignore it.
    let totalTests: Int?
    /// ISO-8601 timestamp of when the run started (client clock); sent as `started_at`.
    /// Additive/nullable — older Workers ignore it.
    let startedAt: String?

    init(shopCode: String? = nil, pairingToken: String? = nil, platform: String = "ios",
         deviceIdentifier: String? = nil, deviceDescription: String? = nil,
         imei: String? = nil, serial: String? = nil, reportID: String? = nil,
         overallResult: String? = nil, totalTests: Int? = nil, startedAt: String? = nil) {
        self.shopCode = shopCode
        self.pairingToken = pairingToken
        self.platform = platform
        self.deviceIdentifier = deviceIdentifier
        self.deviceDescription = deviceDescription
        self.imei = imei
        self.serial = serial
        self.reportID = reportID
        self.overallResult = overallResult
        self.totalTests = totalTests
        self.startedAt = startedAt
    }
}

/// Response for session create (public + staff share these fields).
struct DiagnosticSessionResponse: Codable, Sendable {
    let sessionId: String
    let sessionToken: String
    let expiresAt: String?
    /// The shop's company name (public shop-code path) — used for "Welcome back …". Optional;
    /// absent on older Workers / staff path.
    let companyName: String?
}

/// Request body for POST /api/diagnostics/results.
struct DiagnosticResultPayload: Codable, Sendable {
    let sessionId: String
    let token: String
    let testName: String
    let status: TestStatus
    let details: [String: String]?
}

/// Local outcome of a single test run (UI + buffering use this).
struct TestOutcome: Identifiable, Sendable {
    let id: String          // test id, e.g. "camera_rear"
    let name: String        // display name
    var status: TestStatus
    var details: [String: String]?
}
