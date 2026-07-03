import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryGroupSelectorTests: XCTestCase {
    final class Mock: InventoryServingStub {
        var assignedIds: [String]?
        var result = BulkAssignGroupsResult(groupsAdded: 0, groupsRemoved: 0, assetsAffected: 1)
        override func bulkAssignGroups(assetId: String, groupIds: [String]) async throws -> BulkAssignGroupsResult {
            assignedIds = groupIds; return result
        }
    }
    func testManageGroupsSendsDesiredSetAndPostsNotification() async {
        let mock = Mock()
        let vm = InventoryDetailViewModel(assetId: "a1", service: mock)
        var notified = false
        let token = NotificationCenter.default.addObserver(forName: .inventoryAssetDidChange, object: nil, queue: nil) { _ in notified = true }
        defer { NotificationCenter.default.removeObserver(token) }
        await vm.manageGroups(groupIds: ["g1", "g2"])
        XCTAssertEqual(mock.assignedIds, ["g1", "g2"])
        XCTAssertTrue(notified)
    }
    func testSiblingMessageForSkuPropagation() {
        let r = BulkAssignGroupsResult(groupsAdded: 1, groupsRemoved: 0, assetsAffected: 3, siblingMatch: "sku", skuValue: "SCR-14")
        XCTAssertEqual(InventoryDetailViewModel.siblingMessage(r), #"Groups updated across 3 assets with SKU "SCR-14""#)
        let single = BulkAssignGroupsResult(groupsAdded: 1, groupsRemoved: 0, assetsAffected: 1)
        XCTAssertEqual(InventoryDetailViewModel.siblingMessage(single), "Groups updated")
    }
}
