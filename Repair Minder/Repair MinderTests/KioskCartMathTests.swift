import XCTest
@testable import Repair_Minder

final class KioskCartMathTests: XCTestCase {
    func testSimpleLineNoDiscount() {
        let c = KioskCartMath.computeLineItem(
            KioskCartItem(description: "A", quantity: 2, unitPrice: 10.0, vatRate: 20))
        XCTAssertEqual(c.lineTotal, 20.0, accuracy: 0.0001)
        XCTAssertEqual(c.vatAmount, 4.0, accuracy: 0.0001)
        XCTAssertEqual(c.lineTotalIncVat, 24.0, accuracy: 0.0001)
        XCTAssertEqual(c.effectiveDiscount, 0.0, accuracy: 0.0001)
    }

    func testPercentDiscountTakesPriority() {
        let c = KioskCartMath.computeLineItem(
            KioskCartItem(description: "A", quantity: 1, unitPrice: 100, vatRate: 20,
                          discountPercent: 10, discountAmount: 5))
        XCTAssertEqual(c.effectiveDiscount, 10.0, accuracy: 0.0001)
        XCTAssertEqual(c.lineTotal, 90.0, accuracy: 0.0001)
        XCTAssertEqual(c.vatAmount, 18.0, accuracy: 0.0001)
    }

    func testAmountDiscountCappedAtGross() {
        let c = KioskCartMath.computeLineItem(
            KioskCartItem(description: "A", quantity: 1, unitPrice: 30, vatRate: 20,
                          discountAmount: 50))
        XCTAssertEqual(c.effectiveDiscount, 30.0, accuracy: 0.0001)
        XCTAssertEqual(c.lineTotal, 0.0, accuracy: 0.0001)
    }

    func testZeroVatRespected() {
        let c = KioskCartMath.computeLineItem(
            KioskCartItem(description: "A", quantity: 1, unitPrice: 50, vatRate: 0))
        XCTAssertEqual(c.vatAmount, 0.0, accuracy: 0.0001)
        XCTAssertEqual(c.lineTotalIncVat, 50.0, accuracy: 0.0001)
    }

    func testCartTotalsNoGlobalDiscount() {
        let items = [
            KioskCartItem(description: "A", quantity: 1, unitPrice: 100, vatRate: 20),
            KioskCartItem(description: "B", quantity: 2, unitPrice: 10, vatRate: 20),
        ]
        let t = KioskCartMath.computeCartTotals(items, globalDiscountPercent: nil, globalDiscountAmount: nil)
        XCTAssertEqual(t.subtotal, 120.0, accuracy: 0.0001)
        XCTAssertEqual(t.vatTotal, 24.0, accuracy: 0.0001)
        XCTAssertEqual(t.grandTotal, 144.0, accuracy: 0.0001)
        XCTAssertEqual(t.discountTotal, 0.0, accuracy: 0.0001)
        XCTAssertEqual(t.amountPaid, 0.0, accuracy: 0.0001)
        XCTAssertEqual(t.balanceDue, 144.0, accuracy: 0.0001)
    }

    func testCartTotalsGlobalPercentScalesVat() {
        let items = [KioskCartItem(description: "A", quantity: 1, unitPrice: 100, vatRate: 20)]
        let t = KioskCartMath.computeCartTotals(items, globalDiscountPercent: 10, globalDiscountAmount: nil)
        XCTAssertEqual(t.subtotal, 90.0, accuracy: 0.0001)
        XCTAssertEqual(t.vatTotal, 18.0, accuracy: 0.0001)
        XCTAssertEqual(t.grandTotal, 108.0, accuracy: 0.0001)
        XCTAssertEqual(t.globalDiscount, 10.0, accuracy: 0.0001)
        XCTAssertEqual(t.discountTotal, 10.0, accuracy: 0.0001)
    }

    func testPercentDiscountClampedTo100() {
        // A bad 150% discount must never produce a negative line/total.
        let line = KioskCartMath.computeLineItem(
            KioskCartItem(description: "A", quantity: 1, unitPrice: 100, vatRate: 20, discountPercent: 150))
        XCTAssertEqual(line.effectiveDiscount, 100.0, accuracy: 0.0001)   // capped at gross
        XCTAssertEqual(line.lineTotal, 0.0, accuracy: 0.0001)

        let totals = KioskCartMath.computeCartTotals(
            [KioskCartItem(description: "A", quantity: 1, unitPrice: 100, vatRate: 20)],
            globalDiscountPercent: 150, globalDiscountAmount: nil)
        XCTAssertGreaterThanOrEqual(totals.grandTotal, 0.0)
        XCTAssertEqual(totals.subtotal, 0.0, accuracy: 0.0001)   // 100% of 100 subtotal
    }

    func testCartTotalsGlobalAmountCapped() {
        let items = [KioskCartItem(description: "A", quantity: 1, unitPrice: 50, vatRate: 20)]
        let t = KioskCartMath.computeCartTotals(items, globalDiscountPercent: nil, globalDiscountAmount: 999)
        XCTAssertEqual(t.globalDiscount, 50.0, accuracy: 0.0001)
        XCTAssertEqual(t.subtotal, 0.0, accuracy: 0.0001)
        XCTAssertEqual(t.grandTotal, 0.0, accuracy: 0.0001)
    }
}
