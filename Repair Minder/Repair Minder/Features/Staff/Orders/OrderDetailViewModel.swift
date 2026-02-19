//
//  OrderDetailViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

@MainActor
final class OrderDetailViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var order: Order?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var isSavingItem = false
    @Published private(set) var isDeletingItem = false
    @Published private(set) var itemError: String?

    // MARK: - Private

    private let orderId: String
    private let apiClient: APIClient

    // MARK: - Initialization

    init(orderId: String, apiClient: APIClient? = nil) {
        self.orderId = orderId
        self.apiClient = apiClient ?? APIClient.shared
    }

    // MARK: - Public Methods

    /// Whether the order can be edited (not collected/despatched)
    var isOrderEditable: Bool {
        guard let order else { return false }
        return order.status != .collectedDespatched
    }

    /// Load order details
    func loadOrder() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let fetchedOrder: Order = try await apiClient.request(.order(id: orderId))
            self.order = fetchedOrder
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Refresh order details
    func refresh() async {
        do {
            let fetchedOrder: Order = try await apiClient.request(.order(id: orderId))
            self.order = fetchedOrder
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Add a new line item. Returns true on success.
    func createItem(_ request: OrderItemRequest) async -> Bool {
        isSavingItem = true
        itemError = nil
        defer { isSavingItem = false }
        do {
            let _: OrderItem = try await apiClient.request(
                .createOrderItem(orderId: orderId),
                body: request
            )
            await refresh()
            return true
        } catch let apiError as APIError {
            itemError = apiError.localizedDescription
            return false
        } catch {
            itemError = error.localizedDescription
            return false
        }
    }

    /// Update an existing line item. Returns true on success.
    func updateItem(itemId: String, request: OrderItemRequest) async -> Bool {
        isSavingItem = true
        itemError = nil
        defer { isSavingItem = false }
        do {
            let _: OrderItem = try await apiClient.request(
                .updateOrderItem(orderId: orderId, itemId: itemId),
                body: request
            )
            await refresh()
            return true
        } catch let apiError as APIError {
            itemError = apiError.localizedDescription
            return false
        } catch {
            itemError = error.localizedDescription
            return false
        }
    }

    /// Delete a line item. Returns true on success.
    func deleteItem(itemId: String) async -> Bool {
        isDeletingItem = true
        itemError = nil
        defer { isDeletingItem = false }
        do {
            try await apiClient.requestVoid(
                .deleteOrderItem(orderId: orderId, itemId: itemId)
            )
            await refresh()
            return true
        } catch let apiError as APIError {
            itemError = apiError.localizedDescription
            return false
        } catch {
            itemError = error.localizedDescription
            return false
        }
    }

    /// Clear item error (called from view alert dismiss)
    func clearItemError() {
        itemError = nil
    }
}
