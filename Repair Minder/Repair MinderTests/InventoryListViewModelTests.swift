import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryListViewModelTests: XCTestCase {

    final class MockService: InventoryServingStub {
        var pages: [[Asset]] = []
        var lastQuery: AssetQuery?
        override func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] {
            lastQuery = filters
            return page <= pages.count ? pages[page - 1] : []
        }
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
