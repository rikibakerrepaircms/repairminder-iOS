import SwiftUI

@MainActor
final class InventoryGroupsListViewModel: ObservableObject {
    enum SortField: String, CaseIterable, Identifiable {
        case name, inStock = "in_stock_count", total = "total_asset_count"
        case linked = "linked_product_count", reorder = "reorder_level", avgCost = "avg_cost"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .name: return "Name"; case .inStock: return "In stock"; case .total: return "Total"
            case .linked: return "Linked products"; case .reorder: return "Reorder level"; case .avgCost: return "Avg cost"
            }
        }
    }

    @Published var groups: [InventoryGroup] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published var errorMessage: String?
    @Published private(set) var knownCategories: [String] = []
    /// Total matching-result count from the last first-page load's `meta.total` (NTH-10b).
    @Published private(set) var total: Int?

    @Published var search = ""
    @Published var category: String?
    @Published var hasProducts = false
    @Published var emptyGroups = false
    @Published var sortField: SortField = .name
    @Published var sortAscending = true

    private let service: InventoryServing
    private let pageSize: Int
    private var page = 1
    private var pendingReload = false

    init(service: InventoryServing? = nil, pageSize: Int = 25) {
        self.service = service ?? InventoryService()
        self.pageSize = pageSize
    }

    func load() async {
        if isLoading { pendingReload = true; return }
        isLoading = true; errorMessage = nil; page = 1
        defer { isLoading = false }
        do {
            let result = try await fetchWithTotal(page: 1)
            groups = result.items
            total = result.total
            let cats = result.items.compactMap { $0.category }.filter { !$0.isEmpty }
            knownCategories = Array(Set(knownCategories + cats)).sorted()
            hasMore = result.items.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
        if pendingReload { pendingReload = false; await load() }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true; defer { isLoadingMore = false }
        do {
            let next = page + 1
            let result = try await fetch(page: next)
            groups.append(contentsOf: result)
            page = next
            hasMore = result.count == pageSize
        } catch { /* keep existing list on pagination failure */ }
    }

    private func fetch(page: Int) async throws -> [InventoryGroup] {
        try await service.listGroups(
            page: page, limit: pageSize,
            search: search.isEmpty ? nil : search,
            category: category,
            hasProducts: hasProducts ? true : nil,
            unlinkedOnly: emptyGroups ? true : nil,
            sortBy: sortField.rawValue,
            sortOrder: sortAscending ? "asc" : "desc")
    }

    private func fetchWithTotal(page: Int) async throws -> (items: [InventoryGroup], total: Int?) {
        try await service.listGroupsWithTotal(
            page: page, limit: pageSize,
            search: search.isEmpty ? nil : search,
            category: category,
            hasProducts: hasProducts ? true : nil,
            unlinkedOnly: emptyGroups ? true : nil,
            sortBy: sortField.rawValue,
            sortOrder: sortAscending ? "asc" : "desc")
    }
}
