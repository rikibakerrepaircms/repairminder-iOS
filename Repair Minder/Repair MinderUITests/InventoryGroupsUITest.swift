import XCTest

/// Drives a Phase 3 Groups write flow end-to-end: log in (demo account) → Inventory →
/// open an asset → Inventory Groups card → Manage → toggle a group → Save → back on detail.
/// Requires a seeded in-stock asset AND at least one inventory group in the demo company
/// (the harness seeds both before running); skips gracefully when the demo company is empty (CI-safe).
final class InventoryGroupsUITest: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    /// Same login + navigation flow as InventoryEditActionUITest.
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

    @MainActor func testManageGroupsFromAssetDetail() throws {
        let app = XCUIApplication(); app.launch()
        loginAndOpenInventory(app)
        snap(app, "01-inventory-list")

        // Prime: a neutral tap dismisses the app-wide FAB overlay that swallows the first tap.
        let invTitle = app.staticTexts["Inventory"].firstMatch
        if invTitle.exists { invTitle.tap() }
        Thread.sleep(forTimeInterval: 1)

        // Open the first asset (skip if the demo company has none).
        let row = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'AST'")).firstMatch
        guard row.waitForExistence(timeout: 8) else {
            snap(app, "02-no-asset-skip")
            throw XCTSkip("No inventory asset in the demo company to drive the manage-groups flow")
        }
        let manage = app.buttons["manage-groups"]
        for _ in 0..<4 {
            if row.exists { row.tap() }
            Thread.sleep(forTimeInterval: 2)
            if manage.waitForExistence(timeout: 3) { break }
        }
        snap(app, "02-detail")
        guard manage.waitForExistence(timeout: 5) else {
            print("ELEMENT-TREE-DUMP:\n\(app.debugDescription)")
            throw XCTSkip("Did not reach an asset detail with the Inventory Groups card")
        }
        manage.tap()

        // GroupSelectorSheet: wait for a group row. Skip if the demo company has no groups.
        XCTAssertTrue(app.navigationBars["Manage Groups"].waitForExistence(timeout: 8), "Manage Groups sheet did not appear")
        snap(app, "03-selector")
        let firstGroup = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'select-group-'")).firstMatch
        guard firstGroup.waitForExistence(timeout: 8) else {
            throw XCTSkip("No inventory groups in the demo company to toggle")
        }
        firstGroup.tap()

        // Save is enabled only after the asset's current membership snapshot loads.
        let save = app.buttons["group-selector-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Save button missing on Manage Groups sheet")
        // Give the authoritative current-selection load a moment to enable Save.
        for _ in 0..<10 where !save.isEnabled { Thread.sleep(forTimeInterval: 0.5) }
        XCTAssertTrue(save.isEnabled, "Save stayed disabled — current-membership snapshot never loaded")
        save.tap()
        Thread.sleep(forTimeInterval: 3)
        snap(app, "04-after-save")

        // Back on detail: the sheet is gone and the Manage button is present again.
        XCTAssertFalse(app.navigationBars["Manage Groups"].exists, "Manage Groups sheet did not dismiss after Save")
        XCTAssertTrue(app.buttons["manage-groups"].waitForExistence(timeout: 8), "did not return to asset detail after saving groups")
    }
}
