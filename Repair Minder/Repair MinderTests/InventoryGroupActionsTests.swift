import XCTest
@testable import Repair_Minder

final class InventoryGroupActionsTests: XCTestCase {
    func testAlreadyLinked() {
        var g = InventoryGroup(id: "g", name: "n"); g.linkedProductCount = 0
        XCTAssertFalse(GroupActions.alreadyLinked(g))
        g.linkedProductCount = 2
        XCTAssertTrue(GroupActions.alreadyLinked(g))
    }
    func testStockColorThresholds() {
        var g = InventoryGroup(id: "g", name: "n")
        g.inStockCount = 0; g.reorderLevel = 5
        XCTAssertEqual(GroupActions.stockLevel(g), .out)
        g.inStockCount = 3; g.reorderLevel = 5
        XCTAssertEqual(GroupActions.stockLevel(g), .low)
        g.inStockCount = 9; g.reorderLevel = 5
        XCTAssertEqual(GroupActions.stockLevel(g), .ok)
        g.inStockCount = 9; g.reorderLevel = 0
        XCTAssertEqual(GroupActions.stockLevel(g), .ok)
    }
}
