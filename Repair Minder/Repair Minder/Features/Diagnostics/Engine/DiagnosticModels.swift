// Features/Diagnostics/Engine/DiagnosticModels.swift
import Foundation

/// Per-test result status (wire value matches Worker: pass|fail|skip|error|partial).
enum TestStatus: String, Codable, Sendable {
    case pass, fail, skip, error, partial
}

/// Request body for POST /api/public/diagnostics/session (shop-code path).
struct CreateSessionRequest: Codable, Sendable {
    let shopCode: String?
    let platform: String
    let deviceIdentifier: String?
    let deviceDescription: String?
    let imei: String?
    let serial: String?

    init(shopCode: String? = nil, platform: String = "ios", deviceIdentifier: String? = nil,
         deviceDescription: String? = nil, imei: String? = nil, serial: String? = nil) {
        self.shopCode = shopCode
        self.platform = platform
        self.deviceIdentifier = deviceIdentifier
        self.deviceDescription = deviceDescription
        self.imei = imei
        self.serial = serial
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
