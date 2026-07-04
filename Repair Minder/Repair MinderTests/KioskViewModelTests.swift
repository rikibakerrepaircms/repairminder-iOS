import XCTest
@testable import Repair_Minder

@MainActor
final class KioskViewModelTests: XCTestCase {

    func makeVM() -> KioskViewModel { KioskViewModel(service: StubKioskService()) }

    func testCardPaymentSuccessMarksReceiptPaid() throws {
        let vm = makeVM()
        let unpaid = KioskOrderResponse(
            id: "o", orderNumber: 5, ticketId: "t",
            client: KioskClient(id: "c", email: nil, firstName: nil, lastName: nil, phone: nil),
            items: [],
            totals: KioskResponseTotals(subtotal: 100, vatTotal: 20, grandTotal: 120,
                discountTotal: 0, globalDiscount: 0, amountPaid: 0, balanceDue: 120),
            payment: nil, globalDiscountPercent: nil, globalDiscountAmount: nil, globalDiscountReason: nil,
            company: nil, location: nil, dates: KioskDates(createdAt: "2026-07-04T00:00:00Z"))
        vm.cardPaymentSucceeded(order: unpaid)
        XCTAssertEqual(vm.mode, .receipt)
        let totals = try XCTUnwrap(vm.completedOrder?.totals)
        XCTAssertEqual(totals.amountPaid, 120, accuracy: 0.001)
        XCTAssertEqual(totals.balanceDue, 0, accuracy: 0.001)
        XCTAssertEqual(vm.completedOrder?.payment?.paymentMethod, "card")
    }

    func testAddAndRemoveItem() {
        let vm = makeVM()
        vm.addItem(KioskCartItem(description: "A", unitPrice: 10))
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.totals.grandTotal, 12.0, accuracy: 0.001)
        vm.removeItem(vm.items[0].id)
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertEqual(vm.totals.grandTotal, 0.0, accuracy: 0.001)
    }

    func testChangeQuantityTrimsAssets() {
        let vm = makeVM()
        var item = KioskCartItem(description: "A", unitPrice: 10, selectedAssets: [
            .init(id: "a1", name: "x", assetTag: nil, cost: nil, serialNumber: nil, locationName: nil, subLocation: nil),
            .init(id: "a2", name: "y", assetTag: nil, cost: nil, serialNumber: nil, locationName: nil, subLocation: nil),
        ])
        item.quantity = 2
        vm.addItem(item)
        vm.setQuantity(vm.items[0].id, 1)
        XCTAssertEqual(vm.items[0].quantity, 1)
        XCTAssertEqual(vm.items[0].selectedAssets.count, 1)
        XCTAssertEqual(vm.items[0].selectedAssets.first?.id, "a1")
    }

    func testGuestCheckoutFlag() {
        let vm = makeVM()
        XCTAssertTrue(vm.isGuestCheckout)
        vm.selectedClient = KioskClientRef(id: "c1", email: "e", firstName: "F", lastName: "L", phone: nil)
        XCTAssertFalse(vm.isGuestCheckout)
    }

    func testCashPaymentCreatesOrderAndGoesToReceipt() async {
        let stub = StubKioskService()
        let vm = KioskViewModel(service: stub)
        vm.addItem(KioskCartItem(description: "A", unitPrice: 10))
        await vm.submitCashOrManual(method: "cash", amount: 12.0, notes: nil)
        XCTAssertEqual(vm.mode, .receipt)
        XCTAssertNotNil(vm.completedOrder)
        XCTAssertNotNil(stub.lastRequest?.payment)
        XCTAssertEqual(stub.lastRequest?.payment?.paymentMethod, "cash")
    }

    func testStartCardPaymentSendsNoPaymentBlock() async {
        let stub = StubKioskService()
        let vm = KioskViewModel(service: stub)
        vm.addItem(KioskCartItem(description: "A", unitPrice: 10))
        let order = await vm.createUnpaidOrderForCard()
        XCTAssertNotNil(order)
        XCTAssertNil(stub.lastRequest?.payment)
    }

    func testCancelCardOrderCallsCancelEndpoint() async {
        let stub = StubKioskService()
        let vm = KioskViewModel(service: stub)
        await vm.cancelUnpaidOrder(id: "order-1")
        XCTAssertEqual(stub.cancelledOrderId, "order-1")
    }

    func testNewSaleResetsState() {
        let vm = makeVM()
        vm.addItem(KioskCartItem(description: "A", unitPrice: 10))
        vm.globalDiscountAmount = 5
        vm.startNewSale()
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertNil(vm.globalDiscountAmount)
        XCTAssertEqual(vm.mode, .shopping)
        XCTAssertNil(vm.completedOrder)
    }

    func testNewClientEmptyIdOmitted() {
        let vm = makeVM()
        vm.addItem(KioskCartItem(description: "A", unitPrice: 10))
        vm.selectedClient = KioskClientRef(id: "", email: "new@x.com", firstName: "New", lastName: nil, phone: nil)
        let req = vm.buildRequestForTest(payment: nil)
        XCTAssertNil(req.clientId)                  // empty id omitted
        XCTAssertEqual(req.clientEmail, "new@x.com")
        XCTAssertFalse(req.guestCheckout)           // has email/name → not guest
    }
}

// Test double
@MainActor
final class StubKioskService: KioskServicing {
    var lastRequest: KioskOrderRequest?
    var cancelledOrderId: String?
    func createOrder(_ request: KioskOrderRequest) async throws -> KioskOrderResponse {
        lastRequest = request
        return KioskOrderResponse(
            id: "order-1", orderNumber: 100000001, ticketId: "t",
            client: KioskClient(id: "c", email: nil, firstName: nil, lastName: nil, phone: nil),
            items: [], totals: KioskResponseTotals(subtotal: 0, vatTotal: 0, grandTotal: 12,
                discountTotal: 0, globalDiscount: 0, amountPaid: request.payment?.amount ?? 0,
                balanceDue: request.payment == nil ? 12 : 0),
            payment: request.payment.map { KioskResponsePayment(id: "p", amount: $0.amount, paymentMethod: $0.paymentMethod, paymentDate: "2026-07-04") },
            globalDiscountPercent: nil, globalDiscountAmount: nil, globalDiscountReason: nil,
            company: nil, location: nil, dates: KioskDates(createdAt: "2026-07-04T00:00:00Z"))
    }
    func cancelOrder(id: String) async throws { cancelledOrderId = id }
    func availableAssets(productTypeId: String?, search: String?) async throws -> [KioskAvailableAsset] { [] }
}
