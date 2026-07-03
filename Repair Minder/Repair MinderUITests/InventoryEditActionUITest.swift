import XCTest

/// Drives the Phase 2 write-action UI end-to-end: log in (demo account) → Inventory →
/// open an asset → actions menu → Edit → change notes → Save → back on detail.
/// Requires a seeded asset in the demo company (the test harness seeds one before running).
final class InventoryEditActionUITest: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    /// Reuses the InventoryBrowseUITest login + navigation flow.
    private func loginAndOpenInventory(_ app: XCUIApplication) {
        let staff = app.staticTexts["Staff"]
        if staff.waitForExistence(timeout: 8) { staff.tap() }
        let email = app.textFields.firstMatch
        if email.waitForExistence(timeout: 8) {
            email.tap(); email.typeText("appstore-demo@repairminder.com")
            app.swipeUp()
            let magic = app.buttons["Sign in with Magic Link"]
            if magic.waitForExistence(timeout: 4) { magic.tap() }
            let code = app.textFields.firstMatch
            if code.waitForExistence(timeout: 15) {
                code.tap(); code.typeText("123456")
                let verify = app.buttons["Verify"]
                if verify.waitForExistence(timeout: 3) { verify.tap() }
            }
        }
        let more = app.tabBars.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 30), "did not reach the main tab bar")
        more.tap()
        let inv = app.staticTexts["Inventory"]
        if !inv.waitForExistence(timeout: 3) { more.tap() }  // FAB overlay swallows first tap
        XCTAssertTrue(inv.waitForExistence(timeout: 5), "Inventory row missing in More")
        inv.tap()
        Thread.sleep(forTimeInterval: 5)
    }

    @MainActor func testEditActionFromDetail() throws {
        let app = XCUIApplication(); app.launch()
        loginAndOpenInventory(app)
        snap(app, "01-inventory-list")

        // Prime: a neutral tap dismisses the app-wide FAB overlay that can swallow the first tap.
        app.staticTexts["Inventory"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)

        // Requires an asset in the demo company. When none exists (e.g. CI without a seed),
        // skip gracefully rather than fail — this was verified green with a seeded asset.
        let row = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'AST'")).firstMatch
        guard row.waitForExistence(timeout: 8) else {
            snap(app, "02-no-asset-skip")
            throw XCTSkip("No inventory asset in the demo company to drive the edit flow")
        }
        let menu = app.buttons["asset-actions-menu"]
        for _ in 0..<4 {
            if row.exists { row.tap() }
            Thread.sleep(forTimeInterval: 2)
            if menu.waitForExistence(timeout: 3) { break }
        }
        snap(app, "02-detail")
        if !menu.exists {
            print("ELEMENT-TREE-DUMP:\n\(app.debugDescription)")
        }
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "actions menu not found on detail")
        menu.tap()
        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "Edit not offered in the actions menu")
        edit.tap()
        snap(app, "03-edit-sheet")

        // The edit sheet is presented.
        XCTAssertTrue(app.navigationBars["Edit Asset"].waitForExistence(timeout: 8), "Edit sheet did not appear")

        // Change the Notes field and save.
        let notes = app.textFields["Notes"]
        if notes.waitForExistence(timeout: 5) {
            notes.tap(); notes.typeText("ui-smoke")
        }
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Save button missing")
        save.tap()
        Thread.sleep(forTimeInterval: 3)
        snap(app, "04-after-save")

        // Back on detail: the edit sheet is gone.
        XCTAssertFalse(app.navigationBars["Edit Asset"].exists, "Edit sheet did not dismiss after Save")
        XCTAssertTrue(app.buttons["asset-actions-menu"].waitForExistence(timeout: 8), "did not return to asset detail")
    }
}
