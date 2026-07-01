//
//  MyQueueViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - My Queue View Model

/// View model for the staff work queue
@MainActor
@Observable
final class MyQueueViewModel {

    // MARK: - Published State

    var devices: [DeviceQueueItem] = []
    var pagination: Pagination?
    var filters: QueueFilters?
    var isLoading = false
    var isLoadingMore = false
    var error: String?

    /// Sub-locations grouped by location id, eager-loaded for the inline
    /// sub-location dropdown (mirrors the Devices page).
    var subLocationsByLocation: [String: [SubLocationChoice]] = [:]

    var selectedCategory: QueueCategory = .all
    var searchText = ""

    // MARK: - Configuration

    private let pageSize = 20

    // MARK: - Computed Properties

    /// Current category counts from filters
    var categoryCounts: QueueFilters.CategoryCounts {
        filters?.categoryCounts ?? QueueFilters.CategoryCounts(repair: 0, buyback: 0, unassigned: 0)
    }

    /// Whether there are more pages to load
    var hasMorePages: Bool {
        pagination?.hasNextPage ?? false
    }

    /// Current page number
    var currentPage: Int {
        pagination?.page ?? 1
    }

    /// Whether the queue is empty
    var isEmpty: Bool {
        devices.isEmpty && !isLoading
    }

    /// Empty state message
    var emptyMessage: String {
        if !searchText.isEmpty {
            return "No devices match your search"
        }
        switch selectedCategory {
        case .all:
            return "Your queue is empty"
        case .repair:
            return "No repair devices in your queue"
        case .buyback:
            return "No buyback devices in your queue"
        case .unassigned:
            return "No unassigned devices"
        }
    }

    /// Engineers for the inline assignment dropdown (mapped to the shared type).
    var engineers: [EngineerFilterInfo] {
        (filters?.engineers ?? []).map { EngineerFilterInfo(id: $0.id, name: $0.name) }
    }

    /// Locations for grouping the sub-location dropdown.
    var locations: [LocationOption] {
        filters?.locations ?? []
    }

    // MARK: - Data Loading

    /// Load the initial queue data
    func loadQueue() async {
        isLoading = true
        error = nil

        do {
            let response = try await fetchQueue(page: 1)
            devices = response.data
            pagination = response.pagination
            filters = response.filters
            Task { await loadSubLocationsIfNeeded() }
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("Failed to load queue: \(error)")
            #endif
        }

        isLoading = false
    }

    /// Refresh the queue (pull-to-refresh)
    func refresh() async {
        await loadQueue()
    }

    /// Load more devices when scrolling
    func loadMoreIfNeeded(currentItem: DeviceQueueItem) async {
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

        do {
            let response = try await fetchQueue(page: currentPage + 1)
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

    /// Set the category filter
    func setCategory(_ category: QueueCategory) async {
        guard category != selectedCategory else { return }
        selectedCategory = category
        await loadQueue()
    }

    /// Set the search text
    func setSearch(_ text: String) async {
        guard text != searchText else { return }
        searchText = text

        // Debounce search - only search after user stops typing
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

        // Check if search text hasn't changed during debounce
        guard text == searchText else { return }

        await loadQueue()
    }

    /// Clear search
    func clearSearch() async {
        searchText = ""
        await loadQueue()
    }

    // MARK: - Inline Assignment

    /// Eager-load sub-locations for every known location (once each).
    func loadSubLocationsIfNeeded() async {
        for location in locations where subLocationsByLocation[location.id] == nil {
            do {
                subLocationsByLocation[location.id] =
                    try await DeviceAssignmentService.subLocations(locationId: location.id)
            } catch {
                subLocationsByLocation[location.id] = []
            }
        }
    }

    private var allSubLocations: [SubLocationChoice] {
        subLocationsByLocation.values.flatMap { $0 }
    }

    /// Reassign a device's engineer (nil clears). Optimistic; reverts on failure.
    func reassignEngineer(_ device: DeviceQueueItem, to engineerId: String?) async {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        let previous = devices[index].assignedEngineer
        devices[index].assignedEngineer = engineerId.flatMap { id in
            engineers.first(where: { $0.id == id }).map { AssignedEngineerInfo(id: $0.id, name: $0.name) }
        }
        do {
            try await DeviceAssignmentService.updateEngineer(deviceId: device.id, source: device.source, engineerId: engineerId)
        } catch {
            devices[index].assignedEngineer = previous
            self.error = "Couldn't update engineer"
        }
    }

    /// Reassign a device's sub-location (nil clears). Optimistic; reverts on failure.
    func reassignSubLocation(_ device: DeviceQueueItem, to subLocationId: String?) async {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        let prevSub = devices[index].subLocation
        let prevSubId = devices[index].subLocationId
        let choice = subLocationId.flatMap { id in allSubLocations.first(where: { $0.id == id }) }
        devices[index].subLocationId = subLocationId
        devices[index].subLocation = choice.map {
            SubLocationInfo(id: $0.id, code: $0.code, description: $0.description,
                            type: $0.type, locationId: $0.locationId)
        }
        do {
            try await DeviceAssignmentService.updateSubLocation(deviceId: device.id, source: device.source, subLocationId: subLocationId)
        } catch {
            devices[index].subLocation = prevSub
            devices[index].subLocationId = prevSubId
            self.error = "Couldn't update location"
        }
    }

    // MARK: - Private Methods

    private func fetchQueue(page: Int) async throws -> MyQueueResponse {
        let categoryValue = selectedCategory == .all ? nil : selectedCategory.rawValue
        let searchValue = searchText.isEmpty ? nil : searchText

        let (data, pagination, filters): ([DeviceQueueItem], Pagination?, QueueFilters?) =
            try await APIClient.shared.requestWithFilters(
                .myQueue(page: page, limit: pageSize, search: searchValue, category: categoryValue)
            )

        return MyQueueResponse(
            data: data,
            pagination: pagination ?? Pagination(page: 1, limit: pageSize, total: 0, totalPages: 0),
            filters: filters ?? QueueFilters(
                deviceTypes: [],
                statuses: [],
                categoryCounts: QueueFilters.CategoryCounts(repair: 0, buyback: 0, unassigned: 0),
                engineers: [],
                locations: []
            )
        )
    }
}
