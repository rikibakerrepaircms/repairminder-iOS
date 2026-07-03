import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryGroupDetailViewModelTests: XCTestCase {
    final class Mock: InventoryServingStub {
        var removed: [String] = []
        var addedTo: [(String, String)] = []
        var assetGroups: [AssetGroupSummary] = []
        override func fetchGroup(id: String) async throws -> InventoryGroup {
            var g = InventoryGroup(id: id, name: "Screens"); g.inStockCount = 3; g.totalAssetCount = 5; return g
        }
        override func fetchGroupAssets(id: String, page: Int, limit: Int) async throws -> [Asset] {
            [Asset(id: "a1", assetTag: "T1", name: "Screen", status: .inStock)]
        }
        override func fetchGroupProducts(id: String) async throws -> [LinkedProduct] {
            [LinkedProduct(id: "p1", name: "Repair")]
        }
        override func addMembership(assetId: String, groupId: String) async throws -> GroupMembership {
            addedTo.append((assetId, groupId)); return GroupMembership(id: "m1")
        }
        override func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { assetGroups }
        override func removeMembership(id: String) async throws { removed.append(id) }
    }

    func testLoadPopulatesGroupAssetsAndProducts() async {
        let vm = InventoryGroupDetailViewModel(groupId: "g1", service: Mock())
        await vm.load()
        XCTAssertEqual(vm.group?.name, "Screens")
        XCTAssertEqual(vm.assets.count, 1)
        XCTAssertEqual(vm.products.count, 1)
    }
    func testAddMemberCallsService() async {
        let mock = Mock()
        let vm = InventoryGroupDetailViewModel(groupId: "g1", service: mock)
        await vm.addMember(assetId: "a9")
        XCTAssertEqual(mock.addedTo.first?.0, "a9")
        XCTAssertEqual(mock.addedTo.first?.1, "g1")
    }
    func testRemoveMemberResolvesMembershipIdThenDeletes() async {
        let mock = Mock()
        mock.assetGroups = [AssetGroupSummary(id: "g1", name: "Screens", sku: nil, category: nil, membershipId: "mem-42")]
        let vm = InventoryGroupDetailViewModel(groupId: "g1", service: mock)
        await vm.removeMember(assetId: "a1")
        XCTAssertEqual(mock.removed, ["mem-42"])
    }
    func testRemoveMemberSurfacesErrorWhenMembershipMissing() async {
        let mock = Mock(); mock.assetGroups = []
        let vm = InventoryGroupDetailViewModel(groupId: "g1", service: mock)
        await vm.removeMember(assetId: "a1")
        XCTAssertTrue(mock.removed.isEmpty)
        XCTAssertNotNil(vm.errorMessage)
    }
}
