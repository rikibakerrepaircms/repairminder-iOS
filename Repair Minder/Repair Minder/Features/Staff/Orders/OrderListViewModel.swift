//
//  OrderListViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

@MainActor
final class OrderListViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var orders: [Order] = []
    @Published private(set) var filters: OrderFilters?
    @Published private(set) var pagination: Pagination?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: String?

    // MARK: - Filter State

    @Published var searchText = ""
    @Published var selectedStatus: String?
    @Published var selectedPaymentStatus: String?
    @Published var selectedLocationId: String?
    @Published var selectedUserId: String?

    // MARK: - Private

    private let apiClient: APIClient
    private var currentPage = 1
    private let pageSize = 20
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    init(apiClient: APIClient? = nil) {
        self.apiClient = apiClient ?? APIClient.shared
    }

    // MARK: - Public Methods

    /// Load initial orders
    func loadOrders() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        currentPage = 1

        do {
            let response = try await fetchOrders(page: 1)
            orders = response.orders
            pagination = response.pagination
            filters = response.filters
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Load more orders (pagination)
    func loadMoreIfNeeded(currentItem: Order) async {
        guard let pagination = pagination,
              pagination.hasNextPage,
              !isLoadingMore,
              let lastOrder = orders.last,
              currentItem.id == lastOrder.id else {
            return
        }

        await loadMore()
    }

    /// Load more orders
    func loadMore() async {
        guard let pagination = pagination,
              pagination.hasNextPage,
              !isLoadingMore else {
            return
        }

        isLoadingMore = true

        do {
            let nextPage = currentPage + 1
            let response = try await fetchOrders(page: nextPage)
            orders.append(contentsOf: response.orders)
            self.pagination = response.pagination
            currentPage = nextPage
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingMore = false
    }

    /// Refresh orders (pull to refresh)
    func refresh() async {
        currentPage = 1
        do {
            let response = try await fetchOrders(page: 1)
            orders = response.orders
            pagination = response.pagination
            filters = response.filters
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Search orders with debounce
    func searchOrders() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await loadOrders()
        }
    }

    /// Apply filter and reload
    func applyFilter() async {
        await loadOrders()
    }

    /// Clear all filters
    func clearFilters() async {
        selectedStatus = nil
        selectedPaymentStatus = nil
        selectedLocationId = nil
        selectedUserId = nil
        searchText = ""
        await loadOrders()
    }

    /// Check if any filters are active
    var hasActiveFilters: Bool {
        selectedStatus != nil ||
        selectedPaymentStatus != nil ||
        selectedLocationId != nil ||
        selectedUserId != nil ||
        !searchText.isEmpty
    }

    // MARK: - Private Methods

    private func fetchOrders(page: Int) async throws -> (orders: [Order], pagination: Pagination, filters: OrderFilters) {
        let endpoint = APIEndpoint.orders(
            page: page,
            limit: pageSize,
            status: selectedStatus,
            paymentStatus: selectedPaymentStatus,
            locationId: selectedLocationId,
            assignedUserId: selectedUserId,
            search: searchText.isEmpty ? nil : searchText
        )

        let (data, pagination, filters): ([Order], Pagination?, OrderFilters?) =
            try await apiClient.requestWithFilters(endpoint)

        return (
            data,
            pagination ?? Pagination(page: page, limit: pageSize, total: 0, totalPages: 0),
            filters ?? OrderFilters(locations: [], users: [], statuses: [], paymentStatuses: [], deviceTypes: [])
        )
    }
}
