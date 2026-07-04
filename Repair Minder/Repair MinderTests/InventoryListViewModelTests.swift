import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryListViewModelTests: XCTestCase {

    final class MockService: InventoryServingStub {
        var pages: [[Asset]] = []
        var total: Int?
        var lastQuery: AssetQuery?
        override func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] {
            lastQuery = filters
            return page <= pages.count ? pages[page - 1] : []
        }
        override func fetchAssetsWithTotal(page: Int, pageSize: Int, filters: AssetQuery) async throws -> (items: [Asset], total: Int?) {
            (try await fetchAssets(page: page, pageSize: pageSize, filters: filters), total)
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

    func testCapturesTotalFromMeta() async {
        let mock = MockService()
        mock.pages = [[asset("1"), asset("2")]]
        mock.total = 42
        let vm = InventoryListViewModel(service: mock, pageSize: 24)
        await vm.loadAssets()
        XCTAssertEqual(vm.total, 42)
    }

    func testStatusPillBuildsQuery() async {
        let mock = MockService()
        mock.pages = [[]]
        let vm = InventoryListViewModel(service: mock, pageSize: 24)
        vm.selectStatus(.deployed)
        await vm.loadAssets()
        XCTAssertEqual(mock.lastQuery?.status, "deployed")
    }

    // MARK: - loadMore vs reload race (MF-4)

    /// Parks the FIRST `loadMore()` fetch (page 2, no status filter) on a continuation so it is
    /// genuinely in-flight when a filter change triggers a reload — this deterministically
    /// exercises the stale-page-discard path (mirrors `GatedService` in
    /// InventoryWriteViewModelTests, adapted to gate loadMore's page-2 fetch instead of the
    /// initial load).
    final class GatedLoadMoreService: InventoryServingStub {
        var pagesRequested: [Int] = []
        var page1Initial: [Asset] = []
        var stalePage2: [Asset] = []
        var reloadPage1: [Asset] = []
        var reloadPage2: [Asset] = []
        private var gate: CheckedContinuation<Void, Never>?
        private var fetchingSignal: CheckedContinuation<Void, Never>?
        private var staleLoadMoreStarted = false

        func waitUntilLoadingMore() async {
            if staleLoadMoreStarted { return }
            await withCheckedContinuation { fetchingSignal = $0 }
        }
        func releaseLoadMore() { gate?.resume(); gate = nil }

        override func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] {
            pagesRequested.append(page)
            if page == 2 && filters.status == nil && !staleLoadMoreStarted {
                staleLoadMoreStarted = true
                fetchingSignal?.resume(); fetchingSignal = nil
                await withCheckedContinuation { gate = $0 }
                return stalePage2
            }
            if page == 1 && filters.status == nil { return page1Initial }
            if page == 1 && filters.status == "damaged" { return reloadPage1 }
            if page == 2 && filters.status == "damaged" { return reloadPage2 }
            return []
        }
    }

    func testLoadMoreDiscardsStalePageWhenQueryChangesMidFlight() async {
        let mock = GatedLoadMoreService()
        mock.page1Initial = [asset("1"), asset("2")]
        mock.stalePage2 = [asset("stale1"), asset("stale2")]
        mock.reloadPage1 = [asset("r1"), asset("r2")]
        mock.reloadPage2 = [asset("r3")]
        let vm = InventoryListViewModel(service: mock, pageSize: 2)

        await vm.loadAssets()
        XCTAssertEqual(vm.assets.map(\.id), ["1", "2"])
        XCTAssertTrue(vm.hasMore)

        let staleLoadMore = Task { await vm.loadMore() }
        await mock.waitUntilLoadingMore()   // loadMore's page-2 fetch (stale filter) now in-flight

        vm.selectedStatus = .damaged
        await vm.loadAssets()               // filter change resets the list mid-flight
        XCTAssertEqual(vm.assets.map(\.id), ["r1", "r2"])

        mock.releaseLoadMore()              // stale page 2 now resolves
        await staleLoadMore.value

        // The stale page must NOT be appended onto the freshly-reloaded list.
        XCTAssertEqual(vm.assets.map(\.id), ["r1", "r2"])
        XCTAssertTrue(vm.hasMore)

        // currentPage must not have been corrupted by the stale completion — the next
        // loadMore() should request page 2 (not page 3, which would skip a page).
        await vm.loadMore()
        XCTAssertEqual(mock.pagesRequested, [1, 2, 1, 2])
        XCTAssertEqual(vm.assets.map(\.id), ["r1", "r2", "r3"])
    }

    // MARK: - loadMore vs refresh race (unchanged query)

    /// Same shape as `GatedLoadMoreService` above, but exercises `refresh()` instead of a
    /// filter change — and critically, `refresh()`'s own page-1 fetch is NOT gated, so it
    /// starts and finishes (flipping `isLoading` back to `false`) entirely while the stale
    /// `loadMore()` page-2 fetch is still parked on the continuation. A guard that only checks
    /// `isLoading` at completion time would be fooled by this ordering and still append the
    /// stale page; the `loadGeneration` counter must catch it instead.
    final class GatedRefreshService: InventoryServingStub {
        var pagesRequested: [Int] = []
        var page1Initial: [Asset] = []
        var stalePage2: [Asset] = []
        var refreshedPage1: [Asset] = []
        var page2AfterRefresh: [Asset] = []
        private var gate: CheckedContinuation<Void, Never>?
        private var fetchingSignal: CheckedContinuation<Void, Never>?
        private var staleLoadMoreStarted = false
        private var page1CallCount = 0

        func waitUntilLoadingMore() async {
            if staleLoadMoreStarted { return }
            await withCheckedContinuation { fetchingSignal = $0 }
        }
        func releaseLoadMore() { gate?.resume(); gate = nil }

        override func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] {
            pagesRequested.append(page)
            if page == 2 && !staleLoadMoreStarted {
                staleLoadMoreStarted = true
                fetchingSignal?.resume(); fetchingSignal = nil
                await withCheckedContinuation { gate = $0 }
                return stalePage2
            }
            if page == 1 {
                page1CallCount += 1
                return page1CallCount == 1 ? page1Initial : refreshedPage1
            }
            return page2AfterRefresh
        }
        override func fetchAssetsWithTotal(page: Int, pageSize: Int, filters: AssetQuery) async throws -> (items: [Asset], total: Int?) {
            (try await fetchAssets(page: page, pageSize: pageSize, filters: filters), nil)
        }
    }

    func testRefreshDiscardsStaleLoadMorePageWithUnchangedQuery() async {
        let mock = GatedRefreshService()
        mock.page1Initial = [asset("1"), asset("2")]
        mock.stalePage2 = [asset("stale1"), asset("stale2")]
        mock.refreshedPage1 = [asset("r1"), asset("r2")]
        mock.page2AfterRefresh = [asset("r3")]
        let vm = InventoryListViewModel(service: mock, pageSize: 2)

        await vm.loadAssets()
        XCTAssertEqual(vm.assets.map(\.id), ["1", "2"])
        XCTAssertTrue(vm.hasMore)

        let staleLoadMore = Task { await vm.loadMore() }
        await mock.waitUntilLoadingMore()   // loadMore's page-2 fetch now in-flight

        await vm.refresh()                  // same query — completes fully before the gate opens
        XCTAssertEqual(vm.assets.map(\.id), ["r1", "r2"])
        XCTAssertFalse(vm.isLoading)         // refresh already finished

        mock.releaseLoadMore()              // stale page 2 now resolves, isLoading is false again
        await staleLoadMore.value

        // The stale page must NOT be appended onto the refreshed list, even though isLoading
        // had already gone back to false by the time it landed.
        XCTAssertEqual(vm.assets.map(\.id), ["r1", "r2"])
        XCTAssertTrue(vm.hasMore)

        // currentPage must not have been corrupted by the stale completion — the next
        // loadMore() should request page 2 (not page 3, which would skip a page).
        await vm.loadMore()
        XCTAssertEqual(mock.pagesRequested, [1, 2, 1, 2])
        XCTAssertEqual(vm.assets.map(\.id), ["r1", "r2", "r3"])
    }
}
