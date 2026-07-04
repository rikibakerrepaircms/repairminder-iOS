import Foundation

@MainActor
final class InventoryListViewModel: ObservableObject {

    // MARK: Published state
    @Published private(set) var assets: [Asset] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published private(set) var error: String?
    /// Total matching-result count from the last first-page load's `meta.total`
    /// (nil until a load completes; not updated by `loadMore()` — see NTH-10b).
    @Published private(set) var total: Int?

    // Filter state (bound to UI)
    @Published var searchText = ""
    @Published var selectedStatus: AssetStatus?
    @Published var selectedCategory: String?
    @Published var selectedLocationId: String?
    @Published var selectedSubLocationId: String?
    @Published var selectedProductTypeId: String?
    @Published var selectedGroupId: String?
    @Published var unassignedOnly = false
    @Published var noProductsOnly = false

    // MARK: Private
    private let service: InventoryServing
    private let pageSize: Int
    private var currentPage = 1
    private var searchTask: Task<Void, Never>?
    /// A filter/search change arrived while a load was in flight — reload once it finishes.
    private var pendingReload = false

    init(service: InventoryServing? = nil, pageSize: Int = 24) {
        self.service = service ?? InventoryService()
        self.pageSize = pageSize
    }

    var activeFilterCount: Int {
        [selectedCategory != nil, selectedLocationId != nil, selectedSubLocationId != nil,
         selectedProductTypeId != nil, selectedGroupId != nil, unassignedOnly, noProductsOnly]
            .filter { $0 }.count
    }

    private var query: AssetQuery {
        AssetQuery(
            status: selectedStatus?.apiValue,
            category: selectedCategory,
            locationId: selectedLocationId,
            subLocationId: selectedSubLocationId,
            productTypeId: selectedProductTypeId,
            groupId: selectedGroupId,
            hasGroups: unassignedOnly ? false : nil,
            hasProducts: noProductsOnly ? false : nil,
            search: searchText.isEmpty ? nil : searchText)
    }

    // MARK: Loading
    func loadAssets() async {
        // Coalesce: a change requested mid-load is not dropped — it reloads after.
        if isLoading { pendingReload = true; return }
        repeat {
            pendingReload = false
            isLoading = true; error = nil; currentPage = 1
            do {
                let result = try await service.fetchAssetsWithTotal(page: 1, pageSize: pageSize, filters: query)
                assets = result.items
                total = result.total
                hasMore = result.items.count == pageSize
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        } while pendingReload
    }

    func loadMoreIfNeeded(currentItem: Asset) async {
        guard hasMore, !isLoadingMore, currentItem.id == assets.last?.id else { return }
        await loadMore()
    }

    /// A snapshot of the query fields sent with a request — used to detect whether the
    /// filters/search changed underneath an in-flight `loadMore()` before its result lands.
    private func currentQuerySnapshot() -> AssetQuery { query }

    func loadMore() async {
        // Coalesce against reloads: don't start a page fetch while a reload is in flight, and
        // don't append a page whose query snapshot no longer matches — a filter/search change
        // that fired loadAssets() mid-flight already reset the list; that reload's result wins.
        guard hasMore, !isLoadingMore, !isLoading else { return }
        let snapshot = currentQuerySnapshot()
        isLoadingMore = true
        do {
            let next = currentPage + 1
            let page = try await service.fetchAssets(page: next, pageSize: pageSize, filters: snapshot)
            if !isLoading && snapshot == currentQuerySnapshot() {
                assets.append(contentsOf: page)
                currentPage = next
                hasMore = page.count == pageSize
            }
        } catch {
            #if DEBUG
            print("[InventoryList] pagination error: \(error)")
            #endif
        }
        isLoadingMore = false
    }

    func refresh() async {
        currentPage = 1
        do {
            let result = try await service.fetchAssetsWithTotal(page: 1, pageSize: pageSize, filters: query)
            assets = result.items
            total = result.total
            hasMore = result.items.count == pageSize
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Filtering
    func selectStatus(_ status: AssetStatus?) {
        selectedStatus = (selectedStatus == status) ? nil : status
        Task { await loadAssets() }
    }

    func applyFilters() { Task { await loadAssets() } }

    func clearFilters() {
        selectedCategory = nil; selectedLocationId = nil; selectedSubLocationId = nil
        selectedProductTypeId = nil; selectedGroupId = nil
        unassignedOnly = false; noProductsOnly = false
        Task { await loadAssets() }
    }

    func searchChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await loadAssets()
        }
    }
}
