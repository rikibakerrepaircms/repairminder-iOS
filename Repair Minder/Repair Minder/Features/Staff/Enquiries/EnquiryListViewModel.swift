//
//  EnquiryListViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI

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

    @Published var selectedStatus: TicketStatus? = .open
    @Published var selectedType: TicketType? = .lead
    @Published var selectedLocationId: String?
    @Published var selectedWorkflowStatus: WorkflowStatusFilter?
    @Published var sortBy: SortOption = .updatedAt
    @Published var sortOrder: SortOrder = .desc

    // MARK: - Pagination

    private var currentPage = 1
    private var totalPages = 1
    private var hasMorePages: Bool { currentPage < totalPages }
    private let pageSize = 20

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
        selectedType != nil || selectedLocationId != nil || selectedWorkflowStatus != nil
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
                    status: selectedStatus?.rawValue,
                    ticketType: selectedType?.rawValue,
                    locationId: selectedLocationId,
                    assignedUserId: nil,
                    workflowStatus: selectedWorkflowStatus?.rawValue,
                    sortBy: sortBy.rawValue,
                    sortOrder: sortOrder.rawValue
                )
            )

            tickets = response.tickets
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
                    status: selectedStatus?.rawValue,
                    ticketType: selectedType?.rawValue,
                    locationId: selectedLocationId,
                    assignedUserId: nil,
                    workflowStatus: selectedWorkflowStatus?.rawValue,
                    sortBy: sortBy.rawValue,
                    sortOrder: sortOrder.rawValue
                )
            )

            tickets.append(contentsOf: response.tickets)
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

    func setStatus(_ status: TicketStatus?) {
        guard selectedStatus != status else { return }
        selectedStatus = status
        Task { await loadTickets() }
    }

    func setType(_ type: TicketType?) {
        guard selectedType != type else { return }
        selectedType = type
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
        selectedType = nil
        selectedLocationId = nil
        selectedWorkflowStatus = nil
        Task { await loadTickets() }
    }

    func setSorting(by: SortOption, order: SortOrder) {
        guard sortBy != by || sortOrder != order else { return }
        sortBy = by
        sortOrder = order
        Task { await loadTickets() }
    }
}
