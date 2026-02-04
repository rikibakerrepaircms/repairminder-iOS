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
    @Published var selectedStatus: OrderStatus?
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
        selectedStatus != nil
    }

    init() {
        setupSearchDebounce()
    }

    func loadOrders() async {
        currentPage = 1
        isLoading = true
        error = nil

        do {
            let response: [Order] = try await APIClient.shared.request(
                .orders(
                    page: currentPage,
                    limit: pageSize,
                    status: selectedStatus?.rawValue,
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
            let response: [Order] = try await APIClient.shared.request(
                .orders(
                    page: currentPage,
                    limit: pageSize,
                    status: selectedStatus?.rawValue,
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

    func applyFilter(status: OrderStatus?) {
        selectedStatus = status
        Task { await loadOrders() }
    }

    func clearFilters() {
        selectedStatus = nil
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
