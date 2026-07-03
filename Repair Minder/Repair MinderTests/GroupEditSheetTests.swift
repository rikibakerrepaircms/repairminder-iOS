import XCTest
@testable import Repair_Minder

@MainActor
final class GroupEditSheetTests: XCTestCase {
    final class Mock: InventoryServingStub {
        var sent: GroupFormRequest?
        override func updateGroup(id: String, body: GroupFormRequest) async throws -> InventoryGroup {
            sent = body; return InventoryGroup(id: id, name: body.name)
        }
    }
    func testPrefillAndSubmitMapsAllFields() async {
        var g = InventoryGroup(id: "g1", name: "Screens")
        g.sku = "SCR"; g.category = "Screens"; g.reorderLevel = 5; g.defaultCost = 12; g.isOem = 1
        let mock = Mock()
        let m = GroupEditModel(group: g, service: mock)
        XCTAssertEqual(m.name, "Screens"); XCTAssertEqual(m.sku, "SCR"); XCTAssertTrue(m.isOem)
        m.name = "Screens v2"; m.reorderLevel = "8"
        let ok = await m.submit()
        XCTAssertTrue(ok)
        XCTAssertEqual(mock.sent?.name, "Screens v2")
        XCTAssertEqual(mock.sent?.reorderLevel, 8)
        XCTAssertEqual(mock.sent?.isOem, 1)
        XCTAssertEqual(mock.sent?.category, "Screens")
    }
    func testEmptyNameBlocksSubmit() async {
        let m = GroupEditModel(group: InventoryGroup(id: "g1", name: "X"), service: Mock())
        m.name = "   "
        let ok = await m.submit()
        XCTAssertFalse(ok); XCTAssertNotNil(m.errorMessage)
    }
}
