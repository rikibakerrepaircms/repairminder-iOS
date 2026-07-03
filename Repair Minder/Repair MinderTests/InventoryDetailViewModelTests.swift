import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryDetailViewModelTests: XCTestCase {
    final class Mock: InventoryServingStub {
        override func fetchAsset(id: String) async throws -> Asset { Asset(id: id, assetTag: "T", name: "Widget", status: .inStock) }
        override func fetchActivity(id: String) async throws -> [AssetActivity] { [AssetActivity(id: "act1")] }
        override func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { [AssetGroupSummary(id: "g1", name: "Screens")] }
    }

    func testLoadDetailPopulatesAllSections() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: Mock())
        await vm.load()
        XCTAssertEqual(vm.asset?.name, "Widget")
        XCTAssertEqual(vm.activity.count, 1)
        XCTAssertEqual(vm.groups.first?.name, "Screens")
        XCTAssertFalse(vm.isLoading)
    }
}
