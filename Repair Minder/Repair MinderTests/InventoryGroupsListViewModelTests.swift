import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryGroupsListViewModelTests: XCTestCase {
    final class Mock: InventoryServingStub {
        var lastParams: (search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?)?
        var groups: [InventoryGroup] = []
        override func listGroups(page: Int, limit: Int, search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?) async throws -> [InventoryGroup] {
            lastParams = (search, category, hasProducts, unlinkedOnly, sortBy, sortOrder)
            return groups
        }
    }
    func testLoadPassesFiltersAndSetsHasMore() async {
        let mock = Mock()
        mock.groups = (0..<25).map { InventoryGroup(id: "g\($0)", name: "n") }
        let vm = InventoryGroupsListViewModel(service: mock, pageSize: 25)
        vm.search = "screen"; vm.hasProducts = true; vm.sortField = .inStock; vm.sortAscending = false
        await vm.load()
        XCTAssertEqual(vm.groups.count, 25)
        XCTAssertTrue(vm.hasMore)
        XCTAssertEqual(mock.lastParams?.search, "screen")
        XCTAssertEqual(mock.lastParams?.hasProducts, true)
        XCTAssertEqual(mock.lastParams?.sortBy, "in_stock_count")
        XCTAssertEqual(mock.lastParams?.sortOrder, "desc")
    }
    func testUnlinkedOnlyMapsToEmptyGroups() async {
        let mock = Mock()
        let vm = InventoryGroupsListViewModel(service: mock, pageSize: 25)
        vm.emptyGroups = true
        await vm.load()
        XCTAssertEqual(mock.lastParams?.unlinkedOnly, true)
    }
}
