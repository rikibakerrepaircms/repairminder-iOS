// Features/Diagnostics/Transport/DiagnosticsBuffer.swift
import Foundation

/// On-device persistence for results that couldn't be POSTed (no network).
/// Hybrid transport (C): the Bridge can later read these JSON files over USB/AFC
/// from the app container's Documents/diagnostics-pending/ and submit them.
enum DiagnosticsBuffer {
    struct PendingResult: Codable, Sendable {
        let testName: String
        let status: String
        let details: [String: String]?
    }
    struct PendingSession: Codable, Sendable {
        let shopCode: String?
        let platform: String
        let deviceDescription: String?
        let imei: String?
        let serial: String?
        let reportID: String?
        let results: [PendingResult]
    }

    static var pendingDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("diagnostics-pending", isDirectory: true)
    }

    /// Persist a session that failed to transmit. Returns the file URL, or nil on failure.
    @discardableResult
    static func save(shopCode: String?, platform: String = "ios", deviceDescription: String?,
                     imei: String?, serial: String?, reportID: String? = nil,
                     outcomes: [TestOutcome]) -> URL? {
        let session = PendingSession(
            shopCode: shopCode, platform: platform, deviceDescription: deviceDescription,
            imei: imei, serial: serial, reportID: reportID,
            results: outcomes.map { PendingResult(testName: $0.id, status: $0.status.rawValue, details: $0.details) })
        do {
            try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
            let url = pendingDirectory.appendingPathComponent("\(UUID().uuidString).json")
            let encoder = JSONEncoder()
            // The Bridge replays these files to the Worker, which expects snake_case keys
            // (test_name, shop_code, device_description …). Match the wire format.
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try encoder.encode(session)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
