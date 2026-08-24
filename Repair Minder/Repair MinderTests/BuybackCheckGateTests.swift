import XCTest
@testable import Repair_Minder

/// The gate that decides whether a buyback device may be added yet.
///
/// Mirrors the web vectors in src/utils/buybackDeviceCheck.test.ts. The two
/// implementations have to agree: a purchase booked on the iPad and the same
/// purchase booked on the dashboard must accept and refuse the same states.
final class BuybackCheckGateTests: XCTestCase {

    private func gate(
        isBuyback: Bool = true,
        identifier: String,
        checked: [String] = [],
        checkedForBuyback: Bool = true,
        failed: [String] = [],
        skipped: [String] = []
    ) -> Bool {
        awaitingBuybackCheck(
            isBuybackDevice: isBuyback,
            identifier: identifier,
            checkedIdentifiers: checked,
            checkedForBuyback: checkedForBuyback,
            failedIdentifiers: failed,
            skippedIdentifiers: skipped
        )
    }

    // MARK: - The gate is only ever shut on a purchase

    func testRepairDeviceIsNeverGated() {
        XCTAssertFalse(gate(isBuyback: false, identifier: ""))
        XCTAssertFalse(gate(isBuyback: false, identifier: "353916100000009"))
    }

    // MARK: - Shut until something has actually happened

    func testUncheckedBuybackDeviceIsGated() {
        XCTAssertTrue(gate(identifier: "353916100000009"))
    }

    func testEmptyIdentifierIsGated() {
        XCTAssertTrue(gate(identifier: "   "))
    }

    // MARK: - The three ways it opens

    func testSuccessfulCheckOpensTheGate() {
        XCTAssertFalse(gate(identifier: "353916100000009", checked: ["353916100000009"]))
    }

    func testFailedCheckOpensTheGate() {
        XCTAssertFalse(gate(identifier: "353916100000009", failed: ["353916100000009"]))
    }

    func testExplicitSkipOpensTheGate() {
        XCTAssertFalse(gate(identifier: "353916100000009", skipped: ["353916100000009"]))
    }

    // MARK: - What must NOT open it

    func testRepairModeCheckDoesNotCountForBuyback() {
        XCTAssertTrue(gate(
            identifier: "353916100000009",
            checked: ["353916100000009"],
            checkedForBuyback: false
        ))
    }

    func testCheckAgainstADifferentIdentifierDoesNotCount() {
        XCTAssertTrue(gate(identifier: "353916100000009", checked: ["111111111111111"]))
    }

    /// A skip is an explicit act against ONE identifier, never inherited by the
    /// next device typed into the same form.
    func testSkipDoesNotCarryToTheNextIdentifier() {
        XCTAssertTrue(gate(identifier: "222222222222222", skipped: ["353916100000009"]))
    }

    func testFailureDoesNotCarryToTheNextIdentifier() {
        XCTAssertTrue(gate(identifier: "222222222222222", failed: ["353916100000009"]))
    }

    // MARK: - Whitespace

    func testIdentifierIsMatchedAfterTrimming() {
        XCTAssertFalse(gate(identifier: "  353916100000009  ", checked: ["353916100000009"]))
        XCTAssertFalse(gate(identifier: "  353916100000009  ", skipped: ["353916100000009"]))
    }
}
