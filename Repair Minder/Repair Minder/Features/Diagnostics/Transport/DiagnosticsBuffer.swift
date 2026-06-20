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
        let results: [PendingResult]
    }

    static var pendingDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("diagnostics-pending", isDirectory: true)
    }

    /// Persist a session that failed to transmit. Returns the file URL, or nil on failure.
    @discardableResult
    static func save(shopCode: String?, platform: String = "ios", deviceDescription: String?,
                     imei: String?, serial: String?, outcomes: [TestOutcome]) -> URL? {
        let session = PendingSession(
            shopCode: shopCode, platform: platform, deviceDescription: deviceDescription,
            imei: imei, serial: serial,
            results: outcomes.map { PendingResult(testName: $0.id, status: $0.status.rawValue, details: $0.details) })
        do {
            try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
            let url = pendingDirectory.appendingPathComponent("\(UUID().uuidString).json")
            let data = try JSONEncoder().encode(session)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
