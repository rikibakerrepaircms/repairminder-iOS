import XCTest
@testable import Repair_Minder

/// Covers the "Allocate to Order" wizard's flow across the two real view models it drives:
/// `DeployViewModel` (order search + line-item lookup) and `InventoryDetailViewModel`
/// (the final allocate call). The wizard's own step/selection state lives in
/// `DeployToOrderWizard`, a SwiftUI `View` — its `private func allocate()` is mirrored here
/// rather than driven through SwiftUI, per project convention of testing view-model logic
/// directly instead of the view layer.
@MainActor
final class DeployToOrderWizardTests: XCTestCase {

    final class WizardSpy: InventoryServingStub {
        var searchedText: String?
        var loadedOrderId: String?
        var allocateBody: AllocateRequest?

        override func searchOrders(search: String) async throws -> [Order] {
            searchedText = search
            let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
            return [try d.decode(Order.self, from: Data(#"{"id":"order1","order_number":42,"status":"pending"}"#.utf8))]
        }
        override func fetchOrderItems(orderId: String) async throws -> [OrderItem] {
            loadedOrderId = orderId
            let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
            return [try d.decode(OrderItem.self, from: Data(#"{"id":"item1","description":"Screen repair","quantity":1,"unit_price":50.0,"vat_rate":20.0}"#.utf8))]
        }
        override func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse {
            allocateBody = body
            return AllocateResponse(success: true, data: Asset(id: id, assetTag: "T", name: "n", status: .allocated),
                                    promptReadyToRepair: nil, allocatedParts: nil, device: nil, recoveredAsset: nil)
        }
    }

    /// Full flow: search orders -> select an order -> load its line items -> select a line
    /// item -> confirm. The confirm step's `AllocateRequest` must carry both `order_id` and
    /// `order_item_id` (the worker's allocate handler reads both to link the asset to the
    /// specific order line, not just the order).
    func testSearchSelectItemConfirmAllocatesWithOrderAndItemIds() async throws {
        let spy = WizardSpy()
        let deployVM = DeployViewModel(service: spy)
        let detailVM = InventoryDetailViewModel(assetId: "a1", service: spy)

        // Step 1: search
        deployVM.orderQuery = "Acme"
        await deployVM.search()
        XCTAssertEqual(spy.searchedText, "Acme")
        let order = try XCTUnwrap(deployVM.orders.first)

        // Step 2: select order -> load its line items
        await deployVM.loadItems(orderId: order.id)
        XCTAssertEqual(spy.loadedOrderId, order.id)
        let item = try XCTUnwrap(deployVM.items.first)

        // Step 3: confirm -> allocate (mirrors DeployToOrderWizard.allocate())
        let body = AllocateRequest(orderId: order.id, deviceId: nil, orderItemId: item.id, deploy: false)
        let resp = await detailVM.allocate(body)

        XCTAssertNotNil(resp)
        XCTAssertEqual(spy.allocateBody?.orderId, "order1")
        XCTAssertEqual(spy.allocateBody?.orderItemId, "item1")
    }

    /// Task 21 (already covered in `AssetActionsTests`, re-asserted here since it's the exact
    /// gate that blocks this wizard's confirm step): allocate is blocked with no line item
    /// selected.
    func testAllocateBlockedWithoutLineItemSelected() {
        XCTAssertFalse(AssetActions.canConfirmDeployToOrder(hasLineItem: false))
        XCTAssertTrue(AssetActions.canConfirmDeployToOrder(hasLineItem: true))
    }
}
