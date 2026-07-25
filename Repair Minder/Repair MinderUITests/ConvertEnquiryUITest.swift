import XCTest

/// Smoke test for the enquiry → order entry point. Verifies the action is
/// offered on a lead and that tapping it reaches the service-type step of the
/// conversion sheet. The conversion itself is not submitted — that would book a
/// real order against the demo company.
final class ConvertEnquiryUITest: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    @MainActor func testConvertToOrderReachesServiceTypeStep() throws {
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

        let enquiries = app.tabBars.buttons["Enquiries"]
        XCTAssertTrue(enquiries.waitForExistence(timeout: 30), "did not reach the main tab bar")
        // The dismiss-FAB overlay swallows the first tap anywhere; retry once.
        // Same workaround as InventoryBrowseUITest.
        enquiries.tap()
        if !app.cells.firstMatch.waitForExistence(timeout: 5) { enquiries.tap() }

        guard app.cells.firstMatch.waitForExistence(timeout: 10) else {
            snap(app, "enquiries-empty")
            throw XCTSkip("Demo company has no enquiries to convert")
        }

        // Enquiries that already have an order deliberately hide the action, so
        // walk the list until we find one that is still a lead.
        let convert = app.buttons["Convert to Order"]
        var opened = false
        for index in 0..<8 where !opened {
            let cell = app.cells.element(boundBy: index)
            guard cell.waitForExistence(timeout: 3) else { break }
            cell.tap()

            // The overflow menu is an unlabelled SF Symbol, so match it by
            // position: the trailing-most button on the detail navigation bar.
            let navBar = app.navigationBars.firstMatch
            XCTAssertTrue(navBar.waitForExistence(timeout: 15), "enquiry detail navigation bar missing")
            guard let menu = navBar.buttons.allElementsBoundByIndex.last else {
                return XCTFail("enquiry detail toolbar has no buttons")
            }
            menu.tap()

            if convert.waitForExistence(timeout: 4) {
                opened = true
            } else {
                // Dismiss the menu, go back, and try the next enquiry.
                app.tap()
                navBar.buttons.element(boundBy: 0).tap()
            }
        }

        guard opened else {
            snap(app, "no-convertible-enquiry")
            throw XCTSkip("No lead without an order in the first 8 demo enquiries")
        }
        convert.tap()

        XCTAssertTrue(
            app.navigationBars["Convert to Order"].waitForExistence(timeout: 10),
            "conversion sheet did not open"
        )
        snap(app, "convert-service-type-step")

        // Pick a service type and confirm the wizard opens on the Customer step
        // with the ticket's client already filled in rather than blank.
        let buyback = app.staticTexts["Buyback"]
        let repair = app.staticTexts["Repair"]
        if buyback.waitForExistence(timeout: 5) {
            buyback.tap()
        } else if repair.waitForExistence(timeout: 5) {
            repair.tap()
        } else {
            return XCTFail("no service type card offered")
        }

        XCTAssertTrue(
            app.staticTexts["Customer"].waitForExistence(timeout: 15),
            "wizard did not reach the Customer step"
        )
        // Intake defaults to Collection for the doorstep flow.
        XCTAssertTrue(
            app.staticTexts["Collection"].waitForExistence(timeout: 5),
            "Collection intake option missing from the Customer step"
        )
        let prefilledEmail = app.textFields.containing(
            NSPredicate(format: "value CONTAINS '@'")
        ).firstMatch
        XCTAssertTrue(prefilledEmail.waitForExistence(timeout: 5), "client email was not prefilled")
        snap(app, "convert-customer-step-prefilled")
    }
}
