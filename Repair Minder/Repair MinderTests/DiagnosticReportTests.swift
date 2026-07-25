// Repair MinderTests/DiagnosticReportTests.swift
import Testing
import Foundation
@testable import Repair_Minder

struct DiagnosticReportTests {

    private let sampleID = "RM-20260621-1342-7F3A9C"

    // MARK: - File name

    @Test func fileNameIsKeyedByReportID() {
        let name = DiagnosticReportHTML.fileName(reportID: sampleID)
        #expect(name == "RepairMinder-Diagnostics-RM-20260621-1342-7F3A9C.pdf")
    }

    @Test func reportIDFormatIsValid() {
        let date = Date(timeIntervalSince1970: 1_770_000_000)
        let a = DiagnosticReportID.generate(date: date)
        let b = DiagnosticReportID.generate(date: date)
        #expect(DiagnosticReportID.isValid(a), "got \(a)")
        #expect(DiagnosticReportID.isValid(b), "got \(b)")
        // Same date/time prefix (timezone-independent comparison), random 6-hex suffix.
        #expect(String(a.prefix(17)) == String(b.prefix(17)))   // "RM-yyyyMMdd-HHmm-"
        #expect(!DiagnosticReportID.isValid("RM-20260621-1342-XYZ"))  // bad suffix rejected
    }

    @MainActor @Test func runnerReportIDIsStableAndResetsWithRun() {
        let runner = DiagnosticRunner(tests: [])
        let first = runner.reportID
        #expect(runner.reportID == first)        // stable across reads within a run
        #expect(DiagnosticReportID.isValid(first))
        runner.reset()
        let second = runner.reportID
        #expect(second != first)                 // a fresh run gets a fresh reference
    }
}
