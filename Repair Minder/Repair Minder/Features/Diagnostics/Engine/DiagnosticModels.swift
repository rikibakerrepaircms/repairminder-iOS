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
    let platform: String
    let deviceIdentifier: String?
    let deviceDescription: String?
    let imei: String?
    let serial: String?
    /// Client-generated run reference (also printed on the customer's PDF) so the results we
    /// log can be matched to the report. Sent as `report_id`; ignored by older Workers.
    let reportID: String?

    init(shopCode: String? = nil, platform: String = "ios", deviceIdentifier: String? = nil,
         deviceDescription: String? = nil, imei: String? = nil, serial: String? = nil,
         reportID: String? = nil) {
        self.shopCode = shopCode
        self.platform = platform
        self.deviceIdentifier = deviceIdentifier
        self.deviceDescription = deviceDescription
        self.imei = imei
        self.serial = serial
        self.reportID = reportID
    }
}

/// Response for session create (public + staff share these fields).
struct DiagnosticSessionResponse: Codable, Sendable {
    let sessionId: String
    let sessionToken: String
    let expiresAt: String?
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
