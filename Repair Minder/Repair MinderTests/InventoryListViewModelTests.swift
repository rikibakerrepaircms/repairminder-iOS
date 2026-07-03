import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryListViewModelTests: XCTestCase {

    final class MockService: InventoryServing {
        var pages: [[Asset]] = []
        var lastQuery: AssetQuery?
        func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] {
            lastQuery = filters
            return page <= pages.count ? pages[page - 1] : []
        }
        func fetchAsset(id: String) async throws -> Asset { fatalError() }
        func fetchAssetByTag(_ tag: String) async throws -> Asset { fatalError() }
        func fetchActivity(id: String) async throws -> [AssetActivity] { [] }
        func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { [] }
        func fetchExternalDeployment(id: String) async throws -> ExternalDeployment { .init() }
        func fetchCategories() async throws -> [String] { [] }
        func fetchGroups(search: String?) async throws -> [AssetGroupListItem] { [] }
        func fetchProductTypes(search: String) async throws -> [ProductTypeOption] { [] }
        func fetchLocations() async throws -> [Location] { [] }
        func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] { [] }
        func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse { fatalError() }
        func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset { fatalError() }
        func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse { fatalError() }
        func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData { fatalError() }
        func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset { fatalError() }
        func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset { fatalError() }
        func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset { fatalError() }
        func deleteAsset(id: String) async throws {}
        func searchOrders(search: String) async throws -> [Order] { [] }
        func fetchOrderItems(orderId: String) async throws -> [OrderItem] { [] }
    }

    private func asset(_ id: String) -> Asset {
        Asset(id: id, assetTag: "T\(id)", name: "n", status: .inStock)
    }

    func testLoadPopulatesItems() async {
        let mock = MockService()
        mock.pages = [[asset("1"), asset("2")]]
        let vm = InventoryListViewModel(service: mock, pageSize: 24)
        await vm.loadAssets()
        XCTAssertEqual(vm.assets.count, 2)
        XCTAssertFalse(vm.isLoading)
    }

    func testHasMoreWhenFullPageReturned() async {
        let mock = MockService()
        mock.pages = [Array(repeating: asset("x"), count: 2), [asset("3")]]
        let vm = InventoryListViewModel(service: mock, pageSize: 2) // full page => hasMore
        await vm.loadAssets()
        XCTAssertTrue(vm.hasMore)
        await vm.loadMore()
        XCTAssertEqual(vm.assets.count, 3)
        XCTAssertFalse(vm.hasMore) // last page returned < pageSize
    }

    func testStatusPillBuildsQuery() async {
        let mock = MockService()
        mock.pages = [[]]
        let vm = InventoryListViewModel(service: mock, pageSize: 24)
        vm.selectStatus(.deployed)
        await vm.loadAssets()
        XCTAssertEqual(mock.lastQuery?.status, "deployed")
    }
}
