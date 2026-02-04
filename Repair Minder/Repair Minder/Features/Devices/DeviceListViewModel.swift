//
//  DeviceListViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import Combine

@MainActor
final class DeviceListViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var searchText: String = ""
    @Published var selectedStatuses: Set<DeviceStatus> = []
    @Published var isQueueMode: Bool = true
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

    func loadDevices() async {
        currentPage = 1
        isLoading = true
        error = nil

        do {
            let response: [Device]

            if isQueueMode {
                response = try await APIClient.shared.request(
                    .myQueue(page: currentPage, limit: pageSize),
                    responseType: [Device].self
                )
            } else {
                // Pass comma-separated statuses if multiple selected
                let statusParam: String? = selectedStatuses.isEmpty
                    ? nil
                    : selectedStatuses.map { $0.rawValue }.joined(separator: ",")

                response = try await APIClient.shared.request(
                    .devices(
                        page: currentPage,
                        limit: pageSize,
                        status: statusParam
                    ),
                    responseType: [Device].self
                )
            }

            devices = filterBySearch(response)
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
            let response: [Device]

            if isQueueMode {
                response = try await APIClient.shared.request(
                    .myQueue(page: currentPage, limit: pageSize),
                    responseType: [Device].self
                )
            } else {
                let statusParam: String? = selectedStatuses.isEmpty
                    ? nil
                    : selectedStatuses.map { $0.rawValue }.joined(separator: ",")

                response = try await APIClient.shared.request(
                    .devices(
                        page: currentPage,
                        limit: pageSize,
                        status: statusParam
                    ),
                    responseType: [Device].self
                )
            }

            devices.append(contentsOf: filterBySearch(response))
            totalPages = response.count == pageSize ? currentPage + 1 : currentPage
        } catch {
            currentPage -= 1
        }
    }

    func refresh() async {
        await loadDevices()
    }

    func toggleFilter(status: DeviceStatus) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }
        Task { await loadDevices() }
    }

    func clearFilters() {
        selectedStatuses.removeAll()
        Task { await loadDevices() }
    }

    private func filterBySearch(_ devices: [Device]) -> [Device] {
        guard !searchText.isEmpty else { return devices }

        let query = searchText.lowercased()
        return devices.filter { device in
            device.displayName.lowercased().contains(query) ||
            (device.clientName?.lowercased().contains(query) ?? false) ||
            (device.serialNumber?.lowercased().contains(query) ?? false) ||
            (device.imei?.lowercased().contains(query) ?? false)
        }
    }

    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.loadDevices() }
            }
            .store(in: &cancellables)
    }
}
