import SwiftUI

enum StockTab: String, CaseIterable, Identifiable {
    case summary = "Summary", hierarchy = "Hierarchy", lowStock = "Low Stock"
    var id: String { rawValue }
}

enum StockSortField: String, CaseIterable, Identifiable {
    case name = "Name", inStock = "In Stock", allocated = "Allocated", total = "Total", reorder = "Min Level"
    var id: String { rawValue }
}

@MainActor
final class StockViewModel: ObservableObject {
    private let service: InventoryServing

    @Published var summary: [StockSummaryItem] = []
    @Published var hierarchy: AssetHierarchyResponse?
    @Published var lowStock: LowStockResponse?
    @Published var isLoading = false
    @Published var error: String?

    // Summary sort/expand
    @Published var sortField: StockSortField = .name
    @Published var sortAscending = true
    @Published var expandedIds: Set<String> = []

    init(service: InventoryServing? = nil) {
        self.service = service ?? InventoryService()
    }

    var sortedSummary: [StockSummaryItem] {
        StockViewModel.sort(summary, by: sortField, ascending: sortAscending)
    }

    /// Pure, testable sort.
    nonisolated static func sort(_ items: [StockSummaryItem], by field: StockSortField, ascending: Bool) -> [StockSummaryItem] {
        let sorted = items.sorted { a, b in
            switch field {
            case .name: return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .inStock: return a.displayInStock < b.displayInStock
            case .allocated: return a.displayAllocated < b.displayAllocated
            case .total: return a.totalCount < b.totalCount
            case .reorder: return a.reorderLevel < b.reorderLevel
            }
        }
        return ascending ? sorted : sorted.reversed()
    }

    func toggleExpand(_ id: String) {
        if expandedIds.contains(id) { expandedIds.remove(id) } else { expandedIds.insert(id) }
    }

    func setSort(_ field: StockSortField) {
        if sortField == field { sortAscending.toggle() } else { sortField = field; sortAscending = true }
    }

    func load(_ tab: StockTab) async {
        isLoading = true; error = nil
        do {
            switch tab {
            case .summary: summary = try await service.fetchStockSummary()
            case .hierarchy: hierarchy = try await service.fetchHierarchy(status: nil)
            case .lowStock: lowStock = try await service.fetchLowStock()
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

/// The `Stock` segment: sub-tabbed analytics (Summary / Hierarchy / Low Stock).
struct InventoryStockView: View {
    @StateObject private var viewModel = StockViewModel()
    @State private var tab: StockTab = .summary
    let onFilterByProductType: (String) -> Void
    let onSelectAsset: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(StockTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .accessibilityIdentifier("stock-tab-picker")

            Group {
                switch tab {
                case .summary:
                    StockSummaryView(viewModel: viewModel, onFilterByProductType: onFilterByProductType)
                case .hierarchy:
                    AssetHierarchyView(viewModel: viewModel, onSelectAsset: onSelectAsset)
                case .lowStock:
                    LowStockView(viewModel: viewModel, onView: onFilterByProductType)
                }
            }
        }
        .task(id: tab) { await viewModel.load(tab) }
    }
}
