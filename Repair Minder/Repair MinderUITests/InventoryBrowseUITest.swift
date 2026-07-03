import XCTest

final class InventoryBrowseUITest: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }
    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    @MainActor func testBrowseInventoryFromMore() throws {
        let app = XCUIApplication(); app.launch()
        // Role selection → Staff (button label is compound; tap the inner static text)
        let staff = app.staticTexts["Staff"]
        if staff.waitForExistence(timeout: 8) { staff.tap() }
        // Magic-link login (demo account; backend accepts static 2FA 123456)
        let email = app.textFields.firstMatch
        if email.waitForExistence(timeout: 8) {
            email.tap(); email.typeText("appstore-demo@repairminder.com")
            app.swipeUp() // dismiss keyboard so Magic Link button is hittable
            let magic = app.buttons["Sign in with Magic Link"]
            if magic.waitForExistence(timeout: 4) { magic.tap() }
            let code = app.textFields.firstMatch
            if code.waitForExistence(timeout: 15) {
                code.tap(); code.typeText("123456")
                let verify = app.buttons["Verify"]
                if verify.waitForExistence(timeout: 3) { verify.tap() }
            }
        }
        // Reach tab bar, open More → Inventory
        let more = app.tabBars.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 30), "did not reach the main tab bar")
        more.tap()
        let inv = app.staticTexts["Inventory"]
        // A full-screen "dismiss FAB" overlay sits above the tab bar while the FAB is visible
        // (Repair_MinderApp.swift .overlay { ... onTapGesture { fabState.hide() } }); it swallows
        // the FIRST tap anywhere (just hiding the FAB) instead of forwarding it to the tab bar.
        // Retry the tap once so the smoke test still reaches the More screen.
        if !inv.waitForExistence(timeout: 3) { more.tap() }
        XCTAssertTrue(inv.waitForExistence(timeout: 5), "Inventory row missing in More")
        inv.tap()
        Thread.sleep(forTimeInterval: 5) // allow list to load (or show empty state)
        snap(app, "inventory-list")
        // If any asset row exists, open it → detail
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5) {
            firstCell.tap()
            Thread.sleep(forTimeInterval: 4)
            snap(app, "inventory-detail")
        } else {
            snap(app, "inventory-list-empty")
        }
    }
}
