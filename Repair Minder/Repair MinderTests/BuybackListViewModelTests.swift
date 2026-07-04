import XCTest
@testable import Repair_Minder

@MainActor
final class BuybackListViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubURLProtocol.self)
    }
    override func tearDown() {
        StubURLProtocol.handler = nil
        URLProtocol.unregisterClass(StubURLProtocol.self)
        super.tearDown()
    }

    private static let twoItemJSON = #"""
    {"success":true,"data":{"items":[{"id":"bb1","status":"purchased"},{"id":"bb2","status":"for_sale"}],
     "pagination":{"page":1,"limit":20,"total":2,"total_pages":1},
     "filters":{"statuses":[{"status":"purchased","count":1},{"status":"for_sale","count":1}],"engineers":[]}}}
    """#

    func testLoadItemsDecodesAndExposesItems() async {
        StubURLProtocol.handler = { _ in (200, Data(Self.twoItemJSON.utf8)) }
        let vm = BuybackListViewModel()
        await vm.loadItems()
        XCTAssertEqual(vm.items.map(\.id), ["bb1", "bb2"])
        XCTAssertEqual(vm.totalCount, 2)
        XCTAssertEqual(vm.statusCounts.map(\.status), ["purchased", "for_sale"])
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    /// State transition: selecting a status filter must be reflected in `hasActiveFilters`
    /// and forwarded to the request as a `status` query item.
    func testApplyFilterSendsSelectedStatusAndUpdatesActiveFlag() async {
        var capturedQuery: String?
        StubURLProtocol.handler = { req in
            capturedQuery = req.url?.query
            return (200, Data(Self.twoItemJSON.utf8))
        }
        let vm = BuybackListViewModel()
        XCTAssertFalse(vm.hasActiveFilters)
        vm.selectedStatus = "for_sale"
        await vm.applyFilter()
        XCTAssertTrue(vm.hasActiveFilters)
        XCTAssertTrue(capturedQuery?.contains("status=for_sale") ?? false, "query was: \(capturedQuery ?? "nil")")
    }

    /// State transition: `clearFilters` must reset every filter field and reload unfiltered.
    func testClearFiltersResetsAllFilterState() async {
        var capturedQuery: String?
        StubURLProtocol.handler = { req in
            capturedQuery = req.url?.query
            return (200, Data(Self.twoItemJSON.utf8))
        }
        let vm = BuybackListViewModel()
        vm.selectedStatus = "for_sale"
        vm.searchText = "iphone"
        vm.selectedLocationId = "loc1"
        vm.selectedEngineerId = "eng1"
        XCTAssertTrue(vm.hasActiveFilters)

        await vm.clearFilters()

        XCTAssertFalse(vm.hasActiveFilters)
        XCTAssertNil(vm.selectedStatus)
        XCTAssertEqual(vm.searchText, "")
        XCTAssertFalse(capturedQuery?.contains("status=") ?? false, "query was: \(capturedQuery ?? "nil")")
        XCTAssertFalse(capturedQuery?.contains("search=") ?? false, "query was: \(capturedQuery ?? "nil")")
    }
}
