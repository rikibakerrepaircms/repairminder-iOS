//
//  ClientListViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import Combine

/// Response wrapper for clients list endpoint
private struct ClientsResponse: Decodable {
    let clients: [Client]
    let pagination: ClientsPagination

    struct ClientsPagination: Decodable {
        let page: Int
        let pages: Int
        let total: Int
        let limit: Int
        let hasMore: Bool

        enum CodingKeys: String, CodingKey {
            case page, pages, total, limit
            case hasMore = "has_more"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
            pages = try container.decodeIfPresent(Int.self, forKey: .pages) ?? 1
            total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
            limit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? 20
            let providedHasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
            hasMore = providedHasMore ?? (page < pages)
        }
    }
}

@MainActor
final class ClientListViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var currentPage = 1
    private var hasMore = true
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()

    var hasMorePages: Bool {
        hasMore
    }

    init() {
        setupSearchDebounce()
    }

    func loadClients() async {
        currentPage = 1
        isLoading = true
        error = nil

        do {
            let response: ClientsResponse = try await APIClient.shared.request(
                .clients(
                    page: currentPage,
                    limit: pageSize,
                    search: searchText.isEmpty ? nil : searchText
                ),
                responseType: ClientsResponse.self
            )
            clients = response.clients
            hasMore = response.pagination.hasMore
            currentPage = response.pagination.page
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMorePages, !isLoading else { return }

        currentPage += 1

        do {
            let response: ClientsResponse = try await APIClient.shared.request(
                .clients(
                    page: currentPage,
                    limit: pageSize,
                    search: searchText.isEmpty ? nil : searchText
                ),
                responseType: ClientsResponse.self
            )
            clients.append(contentsOf: response.clients)
            hasMore = response.pagination.hasMore
        } catch {
            currentPage -= 1
        }
    }

    func refresh() async {
        await loadClients()
    }

    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.loadClients() }
            }
            .store(in: &cancellables)
    }
}
