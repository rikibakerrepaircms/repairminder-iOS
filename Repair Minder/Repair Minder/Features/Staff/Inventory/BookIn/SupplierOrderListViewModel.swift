import Foundation

@MainActor
final class SupplierOrderListViewModel: ObservableObject {
    private let service: InventoryServing

    @Published var orders: [SupplierOrder] = []
    @Published var search = ""
    /// Client-side status filter (the list endpoint matches one exact status; web filters locally).
    @Published var enabledStatuses: Set<String> = ["pending", "ordered", "partial"]
    @Published var isLoading = false
    @Published var error: String?

    static let allStatuses = ["pending", "ordered", "partial", "received", "cancelled"]

    init(service: InventoryServing? = nil) {
        self.service = service ?? InventoryService()
    }

    var filtered: [SupplierOrder] {
        orders.filter { enabledStatuses.contains($0.status) }
    }

    func toggleStatus(_ status: String) {
        if enabledStatuses.contains(status) { enabledStatuses.remove(status) } else { enabledStatuses.insert(status) }
    }

    func load() async {
        isLoading = true; error = nil
        do {
            orders = try await service.listSupplierOrders(page: 1, limit: 50, supplier: search.isEmpty ? nil : search, status: nil)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Cancel an order (allowed unless already received/cancelled). Returns true on success.
    @discardableResult
    func cancel(_ order: SupplierOrder) async -> Bool {
        do {
            _ = try await service.updateSupplierOrder(id: order.id, body: UpdateSupplierOrderRequest(status: "cancelled"))
            await load()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
