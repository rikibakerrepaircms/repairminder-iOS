// Features/Diagnostics/Transport/DiagnosticsBuffer.swift
import Foundation

/// On-device persistence for results that couldn't be POSTed (no network).
/// The app flushes its own buffer on the next diagnostics-flow open (see
/// `DiagnosticsService.flushPending`), replaying each session through `transmit`
/// (create → results → complete) so it never strands `in_progress`. An external
/// replayer (e.g. the Bridge reading these JSON files over USB/AFC from the app
/// container's Documents/diagnostics-pending/) is optional.
enum DiagnosticsBuffer {
    struct PendingResult: Codable, Sendable {
        let testName: String
        let status: String
        let details: [String: String]?
    }
    struct PendingSession: Codable, Sendable {
        let shopCode: String?
        let pairingToken: String?
        let platform: String
        let deviceDescription: String?
        let imei: String?
        let serial: String?
        let reportID: String?
        /// Run verdict ("pass"/"partial"/"fail") preserved so a replay re-sends the same overall_result.
        let overallResult: String?
        let results: [PendingResult]
        /// Always true for app-buffered runs: the replayer must POST /complete after replaying
        /// all results, otherwise the session is stranded `in_progress`.
        let needsComplete: Bool
    }

    static var pendingDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("diagnostics-pending", isDirectory: true)
    }

    /// Persist a session that failed to transmit. Returns the file URL, or nil on failure.
    @discardableResult
    static func save(shopCode: String?, pairingToken: String? = nil, platform: String = "ios",
                     deviceDescription: String?, imei: String?, serial: String?, reportID: String? = nil,
                     overallResult: String? = nil,
                     outcomes: [TestOutcome]) -> URL? {
        let session = PendingSession(
            shopCode: shopCode, pairingToken: pairingToken, platform: platform,
            deviceDescription: deviceDescription, imei: imei, serial: serial, reportID: reportID,
            overallResult: overallResult,
            results: outcomes.map { PendingResult(testName: $0.id, status: $0.status.rawValue, details: $0.details) },
            needsComplete: true)
        do {
            try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
            let url = pendingDirectory.appendingPathComponent("\(UUID().uuidString).json")
            let encoder = JSONEncoder()
            // Saved as snake_case (test_name, shop_code, device_description …) — the same wire
            // format the Worker expects, so flushPending (and any external replayer) can decode
            // and re-send these files unchanged.
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try encoder.encode(session)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// URLs of all buffered (pending) session files. Empty if the directory doesn't exist.
    static func pendingURLs() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: pendingDirectory, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "json" } ?? []
    }

    /// Decode a buffered session. Files are saved with `.convertToSnakeCase`, so decode with
    /// `.convertFromSnakeCase`. Returns nil on any failure (missing/corrupt file).
    static func load(_ url: URL) -> PendingSession? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(PendingSession.self, from: data)
    }

    /// Best-effort removal of a buffered session file.
    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
