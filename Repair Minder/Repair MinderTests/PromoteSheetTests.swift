import XCTest
@testable import Repair_Minder

@MainActor
final class PromoteSheetTests: XCTestCase {
    final class Mock: InventoryServingStub {
        var sent: PromoteGroupRequest?
        var error: Error?
        override func promoteGroup(_ body: PromoteGroupRequest) async throws -> PromoteResult {
            sent = body
            if let error { throw error }
            return PromoteResult(product: PromotedProduct(id: "p1"), component: PromotedComponent(id: "c1"))
        }
    }
    func testPrefillFromGroup() {
        var g = InventoryGroup(id: "g1", name: "iPhone Screen"); g.sku = "SCR-14"; g.category = "Screens"; g.defaultSellPrice = 49
        let m = PromoteSheetModel(group: g, service: Mock())
        XCTAssertEqual(m.name, "iPhone Screen")
        XCTAssertEqual(m.sku, "PROD-SCR-14")
        XCTAssertEqual(m.category, "Screens")
        XCTAssertEqual(m.sellPrice, "49")
    }
    func testSubmitSendsRequest() async {
        var g = InventoryGroup(id: "g1", name: "Screen"); g.sku = "SCR-14"
        let mock = Mock(); let m = PromoteSheetModel(group: g, service: mock)
        m.sellPrice = "89"
        let ok = await m.submit()
        XCTAssertTrue(ok)
        XCTAssertEqual(mock.sent?.groupId, "g1")
        XCTAssertEqual(mock.sent?.productName, "Screen")
        XCTAssertEqual(mock.sent?.defaultSellPrice, 89)
    }
    func testDuplicateSkuMapsToFieldError() async {
        let g = InventoryGroup(id: "g1", name: "Screen")
        let mock = Mock(); mock.error = APIError.serverError(message: "A product with that SKU already exists", code: nil)
        let m = PromoteSheetModel(group: g, service: mock)
        let ok = await m.submit()
        XCTAssertFalse(ok)
        XCTAssertNotNil(m.skuError)
    }
}
