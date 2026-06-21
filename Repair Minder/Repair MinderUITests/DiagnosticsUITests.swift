// Repair MinderUITests/DiagnosticsUITests.swift
import XCTest

final class DiagnosticsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetToRoleSelection"] + extraArgs
        app.launch()
        return app
    }

    /// Open diagnostics, select a single test by id, and Start.
    private func openSelectStart(_ app: XCUIApplication, testRowId: String) {
        let entry = app.buttons["diagnostics-entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        entry.tap()
        let row = app.buttons[testRowId]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(testRowId) should be listed")
        row.tap()
        let start = app.buttons["start-tests"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
    }

    /// Tapping the no-login "Diagnostics" entry opens the test-selection screen.
    func testDiagnosticsEntryOpensFlow() throws {
        let app = launch()
        let entry = app.buttons["diagnostics-entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        entry.tap()
        XCTAssertTrue(app.buttons["select-all"].waitForExistence(timeout: 8),
                      "Test-selection screen should appear")
    }

    /// An automatic test (device info) runs and reaches the summary with an overall result.
    func testAutoTestReachesSummary() throws {
        let app = launch()
        openSelectStart(app, testRowId: "test-row-device_info")
        let overall = app.staticTexts["summary-overall"]
        XCTAssertTrue(overall.waitForExistence(timeout: 15), "Summary should appear after the auto test")
        XCTAssertEqual(overall.label, "Pass", "device_info should pass → overall Pass")
        XCTAssertTrue(app.buttons["send-results"].waitForExistence(timeout: 5))
    }

    /// A subjective interactive test (dead pixel) shows a manual Pass; tapping it reaches the summary.
    /// (Auto-detect tests like touchscreen have no manual Pass — they pass on a real signal.)
    func testInteractiveTestPassReachesSummary() throws {
        let app = launch()
        openSelectStart(app, testRowId: "test-row-color")
        let pass = app.buttons["test-pass"]
        XCTAssertTrue(pass.waitForExistence(timeout: 15), "Manual Pass should appear for the subjective dead-pixel test")
        pass.tap()
        let overall = app.staticTexts["summary-overall"]
        XCTAssertTrue(overall.waitForExistence(timeout: 10), "Summary should appear after passing the interactive test")
        XCTAssertEqual(overall.label, "Pass")
    }

    /// The Summary screen exposes a "Share PDF" control that produces a share sheet.
    func testSharePdfFromSummary() throws {
        let app = launch()
        openSelectStart(app, testRowId: "test-row-device_info")

        XCTAssertTrue(app.staticTexts["summary-overall"].waitForExistence(timeout: 15))
        let share = app.buttons["share-pdf"]
        XCTAssertTrue(share.waitForExistence(timeout: 5), "Share PDF control should be on the Summary")
        XCTAssertTrue(share.isHittable)
        share.tap()

        // The system share sheet (UIActivityViewController) presents the generated PDF.
        let activitySheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(activitySheet.waitForExistence(timeout: 15),
                      "Tapping Share PDF should present the share sheet with the report")
    }

    /// Full transmit flow with a stubbed network: summary → Send results → shop code → submit → success.
    func testSubmitWithShopCode() throws {
        let app = launch(["-uiTestStubTransmit"])
        openSelectStart(app, testRowId: "test-row-device_info")

        let send = app.buttons["send-results"]
        XCTAssertTrue(send.waitForExistence(timeout: 15))
        send.tap()

        let field = app.textFields["shop-code-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText("123456")

        let submit = app.buttons["submit-results"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()

        XCTAssertTrue(app.staticTexts["transmit-success"].waitForExistence(timeout: 10),
                      "Submitting with a shop code should report success")
    }
}
