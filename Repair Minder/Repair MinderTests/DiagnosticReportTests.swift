// Repair MinderTests/DiagnosticReportTests.swift
import Testing
import Foundation
@testable import Repair_Minder

struct DiagnosticReportTests {

    // MARK: - Helpers

    private func item(_ id: String, _ name: String, _ status: TestStatus,
                      _ details: [(String, String)] = []) -> DiagnosticReportData.Item {
        DiagnosticReportData.Item(id: id, name: name, status: status,
                                  details: details.map { (label: $0.0, value: $0.1) })
    }

    private func sampleData(overall: String = "fail", grade: DiagnosticGrade = .bad) -> DiagnosticReportData {
        DiagnosticReportData(
            deviceName: "iPhone 15 Pro",
            osName: "iOS", osVersion: "17.5",
            batteryLevel: "87", batteryState: "unplugged",
            generatedAt: Date(timeIntervalSince1970: 1_770_000_000),
            overall: overall, grade: grade,
            passed: [item("storage", "Storage", .pass, [("Total", "127.5 GB"), ("Free", "103.8 GB")]),
                     item("wifi", "Wi-Fi", .pass)],
            failed: [item("speaker", "Loud Speaker", .fail)],
            skipped: [item("lidar", "LiDAR Scanner", .skip, [("Reason", "unsupported")])],
            deviceInfoRows: [("Device", "iPhone 15 Pro"), ("System Version", "iOS 17.5"), ("Battery Level", "87%")]
        )
    }

    // MARK: - File name

    @Test func fileNameMatchesExpectedPattern() {
        let date = Date(timeIntervalSince1970: 1_770_000_000) // fixed
        let name = DiagnosticReportHTML.fileName(for: date)
        #expect(name.hasPrefix("RepairMinder-Diagnostics-"))
        #expect(name.hasSuffix(".pdf"))
        let regex = try! NSRegularExpression(pattern: #"^RepairMinder-Diagnostics-\d{8}-\d{4}\.pdf$"#)
        let range = NSRange(name.startIndex..., in: name)
        #expect(regex.firstMatch(in: name, range: range) != nil, "got \(name)")
    }

    // MARK: - HTML content

    @Test func htmlListsEverySelectedTest() {
        let html = DiagnosticReportHTML.render(sampleData())
        for testName in ["Storage", "Wi-Fi", "Loud Speaker", "LiDAR Scanner"] {
            #expect(html.contains(testName), "report should list \(testName)")
        }
    }

    @Test func htmlShowsDetailValues() {
        let html = DiagnosticReportHTML.render(sampleData())
        #expect(html.contains("127.5 GB"))
        #expect(html.contains("103.8 GB"))
        #expect(html.contains("87%"))
    }

    @Test func htmlShowsVerdictAndCounts() {
        let html = DiagnosticReportHTML.render(sampleData(overall: "fail"))
        #expect(html.contains("Fail"))
        #expect(html.contains("Overall result"))
        // counts: 2 passed, 1 failed, 1 skipped
        #expect(html.contains(">2<"))
        #expect(html.contains("Passed"))
        #expect(html.contains("Failed"))
        #expect(html.contains("Skipped"))
    }

    @Test func verdictWordTracksOverall() {
        #expect(DiagnosticReportHTML.render(sampleData(overall: "pass")).contains(">Pass<"))
        #expect(DiagnosticReportHTML.render(sampleData(overall: "partial")).contains(">Partial<"))
        #expect(DiagnosticReportHTML.render(sampleData(overall: "fail")).contains(">Fail<"))
    }

    @Test func htmlHasMendmyiTaglineAndBatteryNote() {
        let html = DiagnosticReportHTML.render(sampleData())
        #expect(html.contains("Repair Minder is a mendmyi Platform"))
        #expect(html.contains("IMEI")) // the Bridge-only identity note mentions IMEI
        #expect(html.contains("Device Diagnostic Report"))
    }

    /// Trademark guard: the competitor marks must never appear in our output.
    @Test func htmlContainsNoCompetitorMarks() {
        let html = DiagnosticReportHTML.render(sampleData()).lowercased()
        #expect(!html.contains("m360"))
        #expect(!html.contains("atlas"))
    }

    @Test func htmlEscapesDynamicStrings() {
        let data = DiagnosticReportData(
            deviceName: "Evil <script> & \"co\"", osName: "iOS", osVersion: "17",
            batteryLevel: nil, batteryState: nil,
            generatedAt: Date(timeIntervalSince1970: 1_770_000_000),
            overall: "pass", grade: .excellent,
            passed: [], failed: [], skipped: [], deviceInfoRows: [])
        let html = DiagnosticReportHTML.render(data)
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;"))
    }

    @Test func htmlFallsBackToWordmarkWithoutLogos() {
        let html = DiagnosticReportHTML.render(sampleData(), assets: .init())
        #expect(html.contains("RepairMinder") || html.contains("Repair<span"))
        #expect(html.contains("mendmyi"))
    }

    // MARK: - Detail formatter

    @Test func formatterPrettifiesKeysAndHidesEmpty() {
        let rows = ReportDetailFormatter.rows(for: [
            "os_version": "17.5",
            "battery_level": "87",
            "cycle_count": "n/a",       // hidden
            "max_touches": "5",
            "blank": ""                 // hidden
        ])
        let dict = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0.value) })
        #expect(dict["OS Version"] == "17.5")
        #expect(dict["Battery Level"] == "87%")
        #expect(dict["Max Touches"] == "5")
        #expect(dict["Cycle Count"] == nil)        // n/a hidden
        #expect(rows.count == 3)
    }

    @Test func formatterPrioritisesImportantKeys() {
        let rows = ReportDetailFormatter.rows(for: ["zebra": "z", "total": "128 GB", "free": "100 GB"])
        // total then free float ahead of alphabetical "zebra"
        #expect(rows.first?.label == "Total")
        #expect(rows.map(\.label) == ["Total", "Free", "Zebra"])
    }

    @Test func formatterAddsUnits() {
        let rows = ReportDetailFormatter.rows(for: ["voltage_mv": "3870", "temperature_c": "31"])
        let dict = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0.value) })
        #expect(dict["Voltage"] == "3870 mV")
        #expect(dict["Temperature"] == "31°C")
    }

    // MARK: - from(runner:)

    @MainActor @Test func fromRunnerPullsDeviceBannerAndGroupsResults() {
        struct FakeTest: DiagnosticTest {
            let id: String; let name: String; let category: TestCategory
            let requiresInteraction = false; let isSupported = true
            func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: .pass, details: nil) }
        }
        let tests: [DiagnosticTest] = [
            FakeTest(id: "device_info", name: "Device Info", category: .deviceInfo),
            FakeTest(id: "storage", name: "Storage", category: .hardware),
            FakeTest(id: "speaker", name: "Loud Speaker", category: .audio),
        ]
        let runner = DiagnosticRunner(tests: tests)
        runner.selectAll()
        runner.record(TestOutcome(id: "device_info", name: "Device Info", status: .pass,
                                  details: ["model": "iPhone", "name": "iOS", "os_version": "17.5", "battery_level": "64"]))
        runner.record(TestOutcome(id: "storage", name: "Storage", status: .pass,
                                  details: ["total": "127.5 GB", "free": "100 GB"]))
        runner.record(TestOutcome(id: "speaker", name: "Loud Speaker", status: .fail, details: nil))

        let data = DiagnosticReportData.from(runner: runner, deviceName: "iPhone 15 Pro",
                                             generatedAt: Date(timeIntervalSince1970: 1_770_000_000))
        #expect(data.deviceName == "iPhone 15 Pro")
        #expect(data.batteryLevel == "64")
        #expect(data.osVersion == "17.5")
        #expect(data.failedCount == 1)
        #expect(data.passedCount == 2)             // device_info + storage
        #expect(data.overall == "fail")
        // device-info table carries identity + storage capacity rows
        let labels = data.deviceInfoRows.map(\.label)
        #expect(labels.contains("Device"))
        #expect(labels.contains("Storage Capacity"))
    }
}
