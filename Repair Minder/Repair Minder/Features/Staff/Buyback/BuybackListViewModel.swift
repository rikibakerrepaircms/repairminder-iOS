//
//  BuybackListViewModel.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import Foundation

@MainActor
final class BuybackListViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var items: [BuybackItem] = []
    @Published private(set) var pagination: Pagination?
    @Published private(set) var filters: BuybackFilters?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: String?

    // Filter state
    @Published var searchText = ""
    @Published var selectedStatus: String?
    @Published var selectedLocationId: String?
    @Published var selectedEngineerId: String?

    // MARK: - Private

    private let apiClient: APIClient
    private var currentPage = 1
    private let pageSize = 20
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    init(apiClient: APIClient? = nil) {
        self.apiClient = apiClient ?? APIClient.shared
    }

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        selectedStatus != nil || selectedLocationId != nil || selectedEngineerId != nil || !searchText.isEmpty
    }

    var statusCounts: [BuybackStatusCount] {
        filters?.statuses ?? []
    }

    var totalCount: Int {
        pagination?.total ?? 0
    }

    // MARK: - Data Loading

    func loadItems() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        currentPage = 1

        do {
            let response = try await fetchItems(page: 1)
            items = response.items
            pagination = response.pagination
            filters = response.filters
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: BuybackItem) async {
        guard let pagination,
              pagination.hasNextPage,
              !isLoadingMore,
              let lastItem = items.last,
              currentItem.id == lastItem.id else { return }

        await loadMore()
    }

    func loadMore() async {
        guard let pagination,
              pagination.hasNextPage,
              !isLoadingMore else { return }

        isLoadingMore = true

        do {
            let nextPage = currentPage + 1
            let response = try await fetchItems(page: nextPage)
            items.append(contentsOf: response.items)
            self.pagination = response.pagination
            currentPage = nextPage
        } catch {
            #if DEBUG
            print("[BuybackList] Pagination error: \(error)")
            #endif
        }

        isLoadingMore = false
    }

    func refresh() async {
        currentPage = 1
        do {
            let response = try await fetchItems(page: 1)
            items = response.items
            pagination = response.pagination
            filters = response.filters
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Filtering

    func selectStatus(_ status: String?) {
        selectedStatus = (selectedStatus == status) ? nil : status
        Task { await loadItems() }
    }

    func applyFilter() async {
        await loadItems()
    }

    func clearFilters() async {
        selectedStatus = nil
        selectedLocationId = nil
        selectedEngineerId = nil
        searchText = ""
        await loadItems()
    }

    // MARK: - Search (debounced)

    func searchItems() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await loadItems()
        }
    }

    // MARK: - Private

    private func fetchItems(page: Int) async throws -> BuybackListResponse {
        let url = buildURL(page: page)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = apiClient.tokenProvider?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Response shape: { success, data: { items, pagination, filters } }
        struct Envelope: Decodable {
            let success: Bool
            let data: BuybackListResponse
        }

        let envelope = try decoder.decode(Envelope.self, from: data)
        return envelope.data
    }

    private func buildURL(page: Int) -> URL {
        var components = URLComponents(string: "https://api.repairminder.com/api/buyback")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(pageSize)")
        ]

        if let status = selectedStatus {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if !searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: searchText))
        }
        if let locationId = selectedLocationId {
            queryItems.append(URLQueryItem(name: "location_id", value: locationId))
        }
        if let engineerId = selectedEngineerId {
            queryItems.append(URLQueryItem(name: "engineer_id", value: engineerId))
        }

        components.queryItems = queryItems
        return components.url!
    }
}
