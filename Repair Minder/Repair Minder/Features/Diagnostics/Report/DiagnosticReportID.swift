// Features/Diagnostics/Report/DiagnosticReportID.swift
import Foundation

/// A unique, human-usable reference generated once per diagnostic run. The same value is
/// printed on the PDF, used as the file name and document name, and sent to the Worker with
/// the results so a customer's report can be matched to what we logged.
/// Format: `RM-yyyyMMdd-HHmm-XXXXXX` (date/time + 24 random bits) — sortable, readable,
/// filename-safe, and unique per run for a single device.
enum DiagnosticReportID {
    static func generate(date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmm"
        let suffix = String(format: "%06X", UInt32.random(in: 0...0xFF_FFFF))
        return "RM-\(f.string(from: date))-\(suffix)"
    }

    /// Validates the canonical shape (used by tests and as a defensive guard).
    static func isValid(_ id: String) -> Bool {
        id.range(of: "^RM-\\d{8}-\\d{4}-[0-9A-F]{6}$", options: .regularExpression) != nil
    }
}
