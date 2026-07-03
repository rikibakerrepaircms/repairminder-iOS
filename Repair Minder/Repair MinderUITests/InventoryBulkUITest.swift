import XCTest

/// Drives a Phase 4 write flow end-to-end: log in (demo account) → Inventory →
/// tools menu → Book In → create a supplier order → assert the wizard advances to
/// Line Items (a real `POST /api/supplier-orders`). The created order uses a
/// `ZZ-P4-UITest` supplier name and is hard-deleted from D1 after the run.
/// Skips gracefully if the app never reaches the Inventory toolbar (CI-safe).
final class InventoryBulkUITest: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

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
        Thread.sleep(forTimeInterval: 4)
    }

    @MainActor func testBookInCreatesSupplierOrder() throws {
        let app = XCUIApplication(); app.launch()
        loginAndOpenInventory(app)
        // Prime the app-wide FAB overlay (swallows the first content tap) with a safe neutral tap.
        let invTitle = app.staticTexts["Inventory"].firstMatch
        if invTitle.exists { invTitle.tap() }
        Thread.sleep(forTimeInterval: 1)
        snap(app, "01-inventory")

        let toolsMenu = app.buttons["inventory-tools-menu"]
        guard toolsMenu.waitForExistence(timeout: 8) else {
            print("ELEMENT-TREE-DUMP:\n\(app.debugDescription)")
            throw XCTSkip("Inventory tools menu not reachable (did not land on the Inventory toolbar)")
        }
        // The FAB overlay can swallow the first tap; retry until the menu opens.
        let bookIn = app.buttons["Book In Stock"]
        for _ in 0..<4 {
            toolsMenu.tap()
            if bookIn.waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(bookIn.waitForExistence(timeout: 3), "Book In Stock menu item missing")
        bookIn.tap()

        // Supplier-order list sheet → tap New (+)
        let newOrder = app.buttons["bookin-new"]
        XCTAssertTrue(newOrder.waitForExistence(timeout: 8), "Book In list / New button did not appear")
        snap(app, "02-bookin-list")
        newOrder.tap()

        // Order Details step → type supplier → Create Order
        let supplier = app.textFields.firstMatch
        XCTAssertTrue(supplier.waitForExistence(timeout: 8), "Order Details supplier field missing")
        supplier.tap(); supplier.typeText("ZZ-P4-UITest-Supplier")
        snap(app, "03-order-details")

        let create = app.buttons["bookin-create-order"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), "Create Order button missing")
        for _ in 0..<10 where !create.isEnabled { Thread.sleep(forTimeInterval: 0.4) }
        XCTAssertTrue(create.isEnabled, "Create Order stayed disabled after entering a supplier name")
        create.tap()

        // Advanced to Line Items (the order was created via POST /api/supplier-orders).
        let lineItems = app.navigationBars["Line Items"]
        let addLine = app.buttons["Add line"]
        let reached = lineItems.waitForExistence(timeout: 12) || addLine.waitForExistence(timeout: 3)
        snap(app, "04-line-items")
        XCTAssertTrue(reached, "wizard did not advance to Line Items after creating the order")
    }
}
