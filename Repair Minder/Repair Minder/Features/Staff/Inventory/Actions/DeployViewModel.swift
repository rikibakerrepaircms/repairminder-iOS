import Foundation

@MainActor
final class DeployViewModel: ObservableObject {
    @Published var orderQuery = ""
    @Published private(set) var orders: [Order] = []
    @Published private(set) var items: [OrderItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingItems = false

    private let service: InventoryServing
    private var searchTask: Task<Void, Never>?
    // InventoryService.init is @MainActor-isolated — use optional + nil-coalesce (not a default arg value).
    init(service: InventoryServing? = nil) { self.service = service ?? InventoryService() }

    func searchChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await search()
        }
    }
    func search() async {
        guard !orderQuery.isEmpty else { orders = []; return }
        isSearching = true
        orders = (try? await service.searchOrders(search: orderQuery)) ?? []
        isSearching = false
    }
    func loadItems(orderId: String) async {
        isLoadingItems = true
        items = (try? await service.fetchOrderItems(orderId: orderId)) ?? []
        isLoadingItems = false
    }
}
