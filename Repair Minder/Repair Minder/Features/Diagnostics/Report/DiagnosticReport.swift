// Features/Diagnostics/Report/DiagnosticReport.swift
// The diagnostic report is server-generated (fetched HTML rendered via WKWebView) — see
// DiagnosticReportPDF.swift. This file now only holds the shared file-name helper.
import Foundation

enum DiagnosticReportHTML {
    /// Suggested PDF file/document name, keyed by the run's report id, e.g.
    /// `RepairMinder-Diagnostics-RM-20260621-1342-7F3A9C.pdf`.
    static func fileName(reportID: String) -> String {
        "RepairMinder-Diagnostics-\(reportID).pdf"
    }
}
