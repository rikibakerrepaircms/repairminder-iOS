// Repair MinderUITests/DiagnosticsUITests.swift
import XCTest

final class DiagnosticsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Tapping the no-login "Diagnostics" entry on the landing page opens the flow root.
    func testDiagnosticsEntryOpensFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetToRoleSelection"]
        app.launch()

        let entry = app.buttons["diagnostics-entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "Diagnostics entry button should appear on the landing page")
        entry.tap()

        let selectAll = app.buttons["select-all"]
        XCTAssertTrue(selectAll.waitForExistence(timeout: 8),
                      "Test-selection screen should appear after tapping the entry")
    }

    /// Select all tests and start → the runner screen appears.
    func testSelectAllAndStart() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetToRoleSelection"]
        app.launch()

        let entry = app.buttons["diagnostics-entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        entry.tap()

        let selectAll = app.buttons["select-all"]
        XCTAssertTrue(selectAll.waitForExistence(timeout: 8))
        selectAll.tap()

        let start = app.buttons["start-tests"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        // Tests run (host-side device-info is instant) → summary appears with an overall result.
        let overall = app.staticTexts["summary-overall"]
        XCTAssertTrue(overall.waitForExistence(timeout: 15),
                      "Summary should appear after running the selected tests")
        XCTAssertEqual(overall.label, "Pass", "device_info should pass → overall Pass")

        // The Send-results action is available on the summary.
        XCTAssertTrue(app.buttons["send-results"].waitForExistence(timeout: 5))
    }
}
