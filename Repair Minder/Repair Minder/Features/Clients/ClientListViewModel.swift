//
//  ClientListViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import Combine

@MainActor
final class ClientListViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var currentPage = 1
    private var totalPages = 1
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()

    var hasMorePages: Bool {
        currentPage < totalPages
    }

    init() {
        setupSearchDebounce()
    }

    func loadClients() async {
        currentPage = 1
        isLoading = true
        error = nil

        do {
            let response: [Client] = try await APIClient.shared.request(
                .clients(
                    page: currentPage,
                    limit: pageSize,
                    search: searchText.isEmpty ? nil : searchText
                ),
                responseType: [Client].self
            )
            clients = response
            // Estimate if there are more pages based on response count
            totalPages = response.count == pageSize ? currentPage + 1 : currentPage
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMorePages, !isLoading else { return }

        currentPage += 1

        do {
            let response: [Client] = try await APIClient.shared.request(
                .clients(
                    page: currentPage,
                    limit: pageSize,
                    search: searchText.isEmpty ? nil : searchText
                ),
                responseType: [Client].self
            )
            clients.append(contentsOf: response)
            totalPages = response.count == pageSize ? currentPage + 1 : currentPage
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
