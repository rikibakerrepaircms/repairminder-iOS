import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryDetailViewModelTests: XCTestCase {
    final class Mock: InventoryServing {
        func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] { [] }
        func fetchAsset(id: String) async throws -> Asset { Asset(id: id, assetTag: "T", name: "Widget", status: .inStock) }
        func fetchAssetByTag(_ tag: String) async throws -> Asset { fatalError() }
        func fetchActivity(id: String) async throws -> [AssetActivity] { [AssetActivity(id: "act1")] }
        func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { [AssetGroupSummary(id: "g1", name: "Screens")] }
        func fetchExternalDeployment(id: String) async throws -> ExternalDeployment { ExternalDeployment() }
        func fetchCategories() async throws -> [String] { [] }
        func fetchGroups(search: String?) async throws -> [AssetGroupListItem] { [] }
        func fetchProductTypes(search: String) async throws -> [ProductTypeOption] { [] }
        func fetchLocations() async throws -> [Location] { [] }
        func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] { [] }
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
