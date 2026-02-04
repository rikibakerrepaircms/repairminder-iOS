//
//  OrderListViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import Combine

@MainActor
final class OrderListViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var searchText: String = ""
    @Published var selectedStatuses: Set<OrderStatus> = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var currentPage = 1
    private var totalPages = 1
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()

    var hasMorePages: Bool {
        currentPage < totalPages
    }

    var hasActiveFilters: Bool {
        !selectedStatuses.isEmpty
    }

    init() {
        setupSearchDebounce()
    }

    func loadOrders() async {
        currentPage = 1
        isLoading = true
        error = nil

        do {
            // Pass comma-separated statuses if multiple selected
            let statusParam: String? = selectedStatuses.isEmpty
                ? nil
                : selectedStatuses.map { $0.rawValue }.joined(separator: ",")

            let response: [Order] = try await APIClient.shared.request(
                .orders(
                    page: currentPage,
                    limit: pageSize,
                    status: statusParam,
                    search: searchText.isEmpty ? nil : searchText
                ),
                responseType: [Order].self
            )
            orders = response
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
            let statusParam: String? = selectedStatuses.isEmpty
                ? nil
                : selectedStatuses.map { $0.rawValue }.joined(separator: ",")

            let response: [Order] = try await APIClient.shared.request(
                .orders(
                    page: currentPage,
                    limit: pageSize,
                    status: statusParam,
                    search: searchText.isEmpty ? nil : searchText
                ),
                responseType: [Order].self
            )
            orders.append(contentsOf: response)
            totalPages = response.count == pageSize ? currentPage + 1 : currentPage
        } catch {
            currentPage -= 1
        }
    }

    func refresh() async {
        await loadOrders()
    }

    func toggleFilter(status: OrderStatus) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }
        Task { await loadOrders() }
    }

    func clearFilters() {
        selectedStatuses.removeAll()
        Task { await loadOrders() }
    }

    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.loadOrders() }
            }
            .store(in: &cancellables)
    }
}
