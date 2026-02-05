//
//  EnquiryListViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for the enquiry/ticket list
@MainActor
final class EnquiryListViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var tickets: [Ticket] = []
    @Published private(set) var statusCounts: StatusCounts?
    @Published private(set) var ticketTypeCounts: TicketTypeCounts?
    @Published private(set) var companyLocations: [CompanyLocation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: String?

    // MARK: - Filters

    @Published var selectedStatuses: Set<TicketStatus> = [.open]
    @Published var selectedTypes: Set<TicketType> = [.lead]
    @Published var selectedLocationId: String?
    @Published var selectedWorkflowStatus: WorkflowStatusFilter?
    @Published var sortBy: SortOption = .updatedAt
    @Published var sortOrder: SortOrder = .desc
    @Published var searchText: String = ""

    // MARK: - Pagination

    private var currentPage = 1
    private var totalPages = 1
    private var hasMorePages: Bool { currentPage < totalPages }
    private let pageSize = 20

    // MARK: - Search Debounce

    private var searchCancellable: AnyCancellable?

    init() {
        searchCancellable = $searchText
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.loadTickets() }
            }
    }

    // MARK: - Sort Options

    enum SortOption: String, CaseIterable {
        case updatedAt = "updated_at"
        case lastClientUpdate = "last_client_update"
        case createdAt = "created_at"

        var label: String {
            switch self {
            case .updatedAt: return "Last Updated"
            case .lastClientUpdate: return "Last Customer Reply"
            case .createdAt: return "Created"
            }
        }
    }

    enum SortOrder: String, CaseIterable {
        case asc
        case desc

        var label: String {
            switch self {
            case .asc: return "Oldest First"
            case .desc: return "Newest First"
            }
        }
    }

    // MARK: - Computed Properties

    /// Total active tickets count
    var totalActiveCount: Int {
        (statusCounts?.open ?? 0) + (statusCounts?.pending ?? 0) + (statusCounts?.resolved ?? 0)
    }

    /// Whether there are any active filters
    var hasActiveFilters: Bool {
        !selectedTypes.isEmpty || selectedLocationId != nil || selectedWorkflowStatus != nil
    }

    // MARK: - API Parameter Helpers

    /// Single status for API, or nil when 0, 2-3, or all 4 are selected
    private var statusParam: String? {
        guard selectedStatuses.count == 1 else { return nil }
        return selectedStatuses.first?.rawValue
    }

    /// Single type for API, or nil when 0 or both are selected
    private var typeParam: String? {
        guard selectedTypes.count == 1 else { return nil }
        return selectedTypes.first?.rawValue
    }

    /// Whether we need to filter statuses client-side (2 or 3 selected)
    private var needsClientSideStatusFilter: Bool {
        let count = selectedStatuses.count
        return count >= 2 && count < TicketStatus.allCases.count
    }

    /// Returns search text for API, or nil if empty
    private var searchParam: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Client-side search filter on tickets
    private func applySearchFilter(_ tickets: [Ticket]) -> [Ticket] {
        guard let query = searchParam?.lowercased() else { return tickets }
        return tickets.filter { ticket in
            ticket.subject.lowercased().contains(query)
            || ticket.displayNumber.lowercased().contains(query)
            || ticket.client.displayName.lowercased().contains(query)
            || (ticket.order?.status.lowercased().contains(query) ?? false)
            || (ticket.assignedUser?.fullName.lowercased().contains(query) ?? false)
            || (ticket.location?.name.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - Loading

    /// Load tickets with current filters
    func loadTickets() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        currentPage = 1

        do {
            let response: TicketListResponse = try await APIClient.shared.request(
                .tickets(
                    page: 1,
                    limit: pageSize,
                    status: statusParam,
                    ticketType: typeParam,
                    locationId: selectedLocationId,
                    assignedUserId: nil,
                    workflowStatus: selectedWorkflowStatus?.rawValue,
                    sortBy: sortBy.rawValue,
                    sortOrder: sortOrder.rawValue,
                    search: searchParam
                )
            )

            var filtered = response.tickets
            if needsClientSideStatusFilter {
                filtered = filtered.filter { selectedStatuses.contains($0.status) }
            }
            tickets = applySearchFilter(filtered)
            statusCounts = response.statusCounts
            ticketTypeCounts = response.ticketTypeCounts
            companyLocations = response.companyLocations ?? []
            totalPages = response.totalPages
            currentPage = response.page

        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Load more tickets (pagination)
    func loadMoreIfNeeded(currentTicket: Ticket) async {
        guard let index = tickets.firstIndex(where: { $0.id == currentTicket.id }) else { return }

        // Load more when we're 5 items from the end
        if index >= tickets.count - 5 && hasMorePages && !isLoadingMore {
            await loadMoreTickets()
        }
    }

    private func loadMoreTickets() async {
        guard !isLoadingMore && hasMorePages else { return }

        isLoadingMore = true

        do {
            let response: TicketListResponse = try await APIClient.shared.request(
                .tickets(
                    page: currentPage + 1,
                    limit: pageSize,
                    status: statusParam,
                    ticketType: typeParam,
                    locationId: selectedLocationId,
                    assignedUserId: nil,
                    workflowStatus: selectedWorkflowStatus?.rawValue,
                    sortBy: sortBy.rawValue,
                    sortOrder: sortOrder.rawValue,
                    search: searchParam
                )
            )

            var newTickets = response.tickets
            if needsClientSideStatusFilter {
                newTickets = newTickets.filter { selectedStatuses.contains($0.status) }
            }
            tickets.append(contentsOf: applySearchFilter(newTickets))
            currentPage = response.page
            totalPages = response.totalPages

        } catch {
            // Silently fail on pagination errors
            print("Failed to load more tickets: \(error)")
        }

        isLoadingMore = false
    }

    /// Refresh tickets
    func refresh() async {
        await loadTickets()
    }

    // MARK: - Filter Actions

    func toggleStatus(_ status: TicketStatus) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }
        Task { await loadTickets() }
    }

    func toggleType(_ type: TicketType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
        Task { await loadTickets() }
    }

    func setLocation(_ locationId: String?) {
        guard selectedLocationId != locationId else { return }
        selectedLocationId = locationId
        Task { await loadTickets() }
    }

    func setWorkflowStatus(_ status: WorkflowStatusFilter?) {
        guard selectedWorkflowStatus != status else { return }
        selectedWorkflowStatus = status
        Task { await loadTickets() }
    }

    func clearFilters() {
        selectedTypes.removeAll()
        selectedStatuses.removeAll()
        selectedLocationId = nil
        selectedWorkflowStatus = nil
        searchText = ""
        Task { await loadTickets() }
    }

    func setSorting(by: SortOption, order: SortOrder) {
        guard sortBy != by || sortOrder != order else { return }
        sortBy = by
        sortOrder = order
        Task { await loadTickets() }
    }

    // MARK: - Status Updates

    /// Update a single ticket's status
    func updateTicketStatus(_ ticketId: String, to status: TicketStatus) async {
        // Optimistically remove the row with animation (it's moving to a different status tab)
        withAnimation(.easeInOut(duration: 0.3)) {
            tickets.removeAll { $0.id == ticketId }
        }

        let body: [String: String] = ["status": status.rawValue]
        do {
            try await APIClient.shared.requestVoid(
                .updateTicket(id: ticketId),
                body: body
            )
        } catch {
            self.error = error.localizedDescription
        }
        await loadTickets()
    }

    /// Bulk update status for multiple tickets
    func bulkUpdateStatus(_ ticketIds: Set<String>, to status: TicketStatus) async {
        var failedCount = 0
        await withTaskGroup(of: Bool.self) { group in
            for id in ticketIds {
                group.addTask {
                    let body: [String: String] = ["status": status.rawValue]
                    do {
                        try await APIClient.shared.requestVoid(
                            .updateTicket(id: id),
                            body: body
                        )
                        return true
                    } catch {
                        return false
                    }
                }
            }
            for await success in group {
                if !success { failedCount += 1 }
            }
        }
        if failedCount > 0 {
            error = "Failed to update \(failedCount) ticket\(failedCount == 1 ? "" : "s")"
        }
        await loadTickets()
    }
}
