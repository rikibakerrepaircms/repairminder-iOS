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

        let root = app.otherElements["diagnostics-root"]
        let title = app.staticTexts["Device Diagnostics"]
        XCTAssertTrue(root.waitForExistence(timeout: 8) || title.waitForExistence(timeout: 8),
                      "Diagnostics flow root should appear after tapping the entry")
    }
}
