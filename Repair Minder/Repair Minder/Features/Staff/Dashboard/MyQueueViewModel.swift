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
