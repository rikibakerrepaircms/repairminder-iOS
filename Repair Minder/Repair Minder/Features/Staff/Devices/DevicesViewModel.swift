//
//  DevicesViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Devices View Model

/// View model for the device list
@MainActor
@Observable
final class DevicesViewModel {

    // MARK: - Published State

    var devices: [DeviceListItem] = []
    var pagination: Pagination?
    var filters: DeviceListFilters?
    var isLoading = false
    var isLoadingMore = false
    var error: String?

    var filterState = DeviceListFilter()

    // MARK: - Computed Properties

    /// Current category counts from filters
    var categoryCounts: DeviceCategoryCounts {
        filters?.categoryCounts ?? DeviceCategoryCounts(repair: 0, buyback: 0, refurb: 0, unassigned: 0)
    }

    /// Whether there are more pages to load
    var hasMorePages: Bool {
        pagination?.hasNextPage ?? false
    }

    /// Current page number
    var currentPage: Int {
        pagination?.page ?? 1
    }

    /// Whether the device list is empty
    var isEmpty: Bool {
        devices.isEmpty && !isLoading
    }

    /// Empty state message
    var emptyMessage: String {
        if !filterState.search.isEmpty {
            return "No devices match your search"
        }
        switch filterState.workflowCategory {
        case .all:
            return "No devices found"
        case .repair:
            return "No repair devices"
        case .buyback:
            return "No buyback devices"
        case .refurb:
            return "No refurbishment devices"
        case .unassigned:
            return "No unassigned devices"
        }
    }

    /// Available device types for filtering
    var deviceTypes: [DeviceTypeOption] {
        filters?.deviceTypes ?? []
    }

    /// Available engineers for filtering
    var engineers: [EngineerFilterInfo] {
        filters?.engineers ?? []
    }

    /// Available locations for filtering
    var locations: [LocationOption] {
        filters?.locations ?? []
    }

    // MARK: - Data Loading

    /// Load the initial device list
    func loadDevices() async {
        isLoading = true
        error = nil
        filterState.page = 1

        do {
            let response = try await fetchDevices()
            devices = response.data
            pagination = response.pagination
            filters = response.filters
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("Failed to load devices: \(error)")
            #endif
        }

        isLoading = false
    }

    /// Refresh the device list (pull-to-refresh)
    func refresh() async {
        await loadDevices()
    }

    /// Load more devices when scrolling
    func loadMoreIfNeeded(currentItem: DeviceListItem) async {
        // Check if we're at the last few items
        guard let index = devices.firstIndex(where: { $0.id == currentItem.id }),
              index >= devices.count - 3,
              hasMorePages,
              !isLoadingMore else {
            return
        }

        await loadMore()
    }

    /// Load the next page
    func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }

        isLoadingMore = true
        filterState.page = currentPage + 1

        do {
            let response = try await fetchDevices()
            devices.append(contentsOf: response.data)
            pagination = response.pagination
            filters = response.filters
        } catch {
            #if DEBUG
            print("Failed to load more: \(error)")
            #endif
        }

        isLoadingMore = false
    }

    // MARK: - Filtering

    /// Set the workflow category filter
    func setCategory(_ category: WorkflowCategory) async {
        guard category != filterState.workflowCategory else { return }
        filterState.workflowCategory = category
        await loadDevices()
    }

    /// Set the search text
    func setSearch(_ text: String) async {
        guard text != filterState.search else { return }
        filterState.search = text

        // Debounce search - only search after user stops typing
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

        // Check if search text hasn't changed during debounce
        guard text == filterState.search else { return }

        await loadDevices()
    }

    /// Clear search
    func clearSearch() async {
        filterState.search = ""
        await loadDevices()
    }

    /// Set device type filter
    func setDeviceType(_ deviceTypeId: String?) async {
        guard deviceTypeId != filterState.deviceTypeId else { return }
        filterState.deviceTypeId = deviceTypeId
        await loadDevices()
    }

    /// Set engineer filter
    func setEngineer(_ engineerId: String?) async {
        guard engineerId != filterState.engineerId else { return }
        filterState.engineerId = engineerId
        await loadDevices()
    }

    /// Set location filter
    func setLocation(_ locationId: String?) async {
        guard locationId != filterState.locationId else { return }
        filterState.locationId = locationId
        await loadDevices()
    }

    /// Set status filter
    func setStatus(_ status: String?) async {
        guard status != filterState.status else { return }
        filterState.status = status
        await loadDevices()
    }

    /// Clear all filters
    func clearFilters() async {
        filterState.reset()
        await loadDevices()
    }

    // MARK: - Scanner Search

    /// Search for a device by serial number or IMEI (scanner lookup)
    func searchBySerialOrIMEI(_ query: String) async -> DeviceListItem? {
        var searchFilter = DeviceListFilter()
        searchFilter.search = query
        searchFilter.limit = 1

        do {
            let (data, _, _): ([DeviceListItem], Pagination?, DeviceListFilters?) =
                try await APIClient.shared.requestWithFilters(.devices(filter: searchFilter))
            return data.first
        } catch {
            #if DEBUG
            print("Scanner lookup failed: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Private Methods

    private func fetchDevices() async throws -> DeviceListResponse {
        let (data, pagination, filters): ([DeviceListItem], Pagination?, DeviceListFilters?) =
            try await APIClient.shared.requestWithFilters(.devices(filter: filterState))

        return DeviceListResponse(
            data: data,
            pagination: pagination ?? Pagination(page: 1, limit: filterState.limit, total: 0, totalPages: 0),
            filters: filters ?? DeviceListFilters(
                deviceTypes: [],
                engineers: [],
                locations: [],
                categoryCounts: DeviceCategoryCounts(repair: 0, buyback: 0, refurb: 0, unassigned: 0)
            )
        )
    }
}
