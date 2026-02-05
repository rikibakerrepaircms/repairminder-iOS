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

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
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
        // Build status filter string
        let statusFilter = selectedStatus

        // Build endpoint with filters
        let endpoint = APIEndpoint.orders(page: page, limit: pageSize, status: statusFilter)

        // For now, use the simple endpoint - additional filters would need URL modification
        // The backend supports: status, payment_status, location_id, assigned_user_id, search

        // Perform request - note: the response structure is different
        // Backend returns { success, data: [orders], pagination, filters }
        // But our APIClient unwraps data, so we need to handle this specially

        let url = buildOrdersURL(page: page)
        let request = try buildRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: nil)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let apiResponse = try decoder.decode(OrdersAPIResponse.self, from: data)

        guard apiResponse.success else {
            throw APIError.serverError(message: apiResponse.error ?? "Unknown error", code: nil)
        }

        return (apiResponse.data, apiResponse.pagination, apiResponse.filters)
    }

    private func buildOrdersURL(page: Int) -> URL {
        var components = URLComponents(string: "https://api.repairminder.com/api/orders")!
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(pageSize))
        ]

        if let status = selectedStatus, !status.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }

        if let paymentStatus = selectedPaymentStatus, !paymentStatus.isEmpty {
            queryItems.append(URLQueryItem(name: "payment_status", value: paymentStatus))
        }

        if let locationId = selectedLocationId, !locationId.isEmpty {
            queryItems.append(URLQueryItem(name: "location_id", value: locationId))
        }

        if let userId = selectedUserId, !userId.isEmpty {
            queryItems.append(URLQueryItem(name: "assigned_user_id", value: userId))
        }

        if !searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: searchText))
        }

        components.queryItems = queryItems
        return components.url!
    }

    private func buildRequest(url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = apiClient.tokenProvider?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}

// MARK: - API Response Types

private struct OrdersAPIResponse: Decodable {
    let success: Bool
    let data: [Order]
    let pagination: Pagination
    let filters: OrderFilters
    let error: String?
}
