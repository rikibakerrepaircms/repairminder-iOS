//
//  ClientListViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

@MainActor
final class ClientListViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var clients: [Client] = []
    @Published private(set) var pagination: Pagination?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: String?

    // MARK: - Filter State

    @Published var searchText = ""

    // MARK: - Private

    private let apiClient: APIClient
    private var currentPage = 1
    private let pageSize = 50
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    init(apiClient: APIClient? = nil) {
        self.apiClient = apiClient ?? APIClient.shared
    }

    // MARK: - Public Methods

    /// Load initial clients
    func loadClients() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        currentPage = 1

        do {
            let response = try await fetchClients(page: 1)
            clients = response.clients
            pagination = response.pagination
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Load more clients (pagination)
    func loadMoreIfNeeded(currentItem: Client) async {
        guard let pagination = pagination,
              pagination.hasNextPage,
              !isLoadingMore,
              let lastClient = clients.last,
              currentItem.id == lastClient.id else {
            return
        }

        await loadMore()
    }

    /// Load more clients
    func loadMore() async {
        guard let pagination = pagination,
              pagination.hasNextPage,
              !isLoadingMore else {
            return
        }

        isLoadingMore = true

        do {
            let nextPage = currentPage + 1
            let response = try await fetchClients(page: nextPage)
            clients.append(contentsOf: response.clients)
            self.pagination = response.pagination
            currentPage = nextPage
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingMore = false
    }

    /// Refresh clients (pull to refresh)
    func refresh() async {
        currentPage = 1
        do {
            let response = try await fetchClients(page: 1)
            clients = response.clients
            pagination = response.pagination
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Search clients with debounce
    func searchClients() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await loadClients()
        }
    }

    // MARK: - Private Methods

    private func fetchClients(page: Int) async throws -> ClientListResponse {
        let url = buildClientsURL(page: page)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = apiClient.tokenProvider?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: nil)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let apiResponse = try decoder.decode(ClientsAPIResponse.self, from: data)

        guard apiResponse.success else {
            throw APIError.serverError(message: apiResponse.error ?? "Unknown error", code: nil)
        }

        return apiResponse.data
    }

    private func buildClientsURL(page: Int) -> URL {
        var components = URLComponents(string: "https://api.repairminder.com/api/clients")!
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(pageSize))
        ]

        if !searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: searchText))
        }

        components.queryItems = queryItems
        return components.url!
    }
}

// MARK: - API Response Types

private struct ClientsAPIResponse: Decodable {
    let success: Bool
    let data: ClientListResponse
    let error: String?
}
