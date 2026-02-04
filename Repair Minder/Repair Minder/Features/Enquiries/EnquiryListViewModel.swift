//
//  EnquiryListViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import Combine

@MainActor
final class EnquiryListViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var enquiries: [Enquiry] = []
    @Published var stats: EnquiryStats = .empty
    @Published var selectedFilter: EnquiryFilter = .all
    @Published var isLoading = false
    @Published var error: Error?
    @Published var filterCounts: [EnquiryFilter: Int] = [:]

    // MARK: - Private Properties
    private var currentPage = 1
    private var hasMore = true
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var hasMorePages: Bool {
        hasMore
    }

    var hasActiveFilters: Bool {
        selectedFilter != .all
    }

    // MARK: - Initialization
    init() {
        setupFilterObserver()
    }

    // MARK: - Private Methods
    private func setupFilterObserver() {
        $selectedFilter
            .dropFirst()
            .sink { [weak self] _ in
                Task {
                    await self?.loadEnquiries()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods
    func loadEnquiries() async {
        isLoading = true
        error = nil
        currentPage = 1

        do {
            let endpoint = APIEndpoint.enquiries(
                page: currentPage,
                limit: pageSize,
                status: selectedFilter.statusValue
            )

            let response: EnquiriesResponse = try await APIClient.shared.request(
                endpoint,
                responseType: EnquiriesResponse.self
            )

            enquiries = response.items
            hasMore = response.pagination.hasMore
            currentPage = response.pagination.page

            // Load stats
            await loadStats()
            await loadFilterCounts()

        } catch {
            self.error = error
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }

        currentPage += 1

        do {
            let endpoint = APIEndpoint.enquiries(
                page: currentPage,
                limit: pageSize,
                status: selectedFilter.statusValue
            )

            let response: EnquiriesResponse = try await APIClient.shared.request(
                endpoint,
                responseType: EnquiriesResponse.self
            )

            enquiries.append(contentsOf: response.items)
            hasMore = response.pagination.hasMore
        } catch {
            self.error = error
            currentPage -= 1
        }
    }

    func refresh() async {
        await loadEnquiries()
    }

    func loadStats() async {
        do {
            let endpoint = APIEndpoint.enquiryStatsEndpoint()
            let statsData: EnquiryStats = try await APIClient.shared.request(
                endpoint,
                responseType: EnquiryStats.self
            )
            stats = statsData
        } catch {
            // Stats are non-critical, silently fail
        }
    }

    func loadFilterCounts() async {
        // Derive from loaded stats
        filterCounts = [
            .all: stats.totalActive,
            .new: stats.newToday,
            .pending: stats.awaitingReply,
            .awaitingCustomer: max(0, stats.totalActive - stats.newToday - stats.awaitingReply)
        ]
    }

    func markAsRead(_ id: String) {
        Task {
            do {
                let endpoint = APIEndpoint.markEnquiryRead(id: id)
                try await APIClient.shared.requestVoid(endpoint)

                // Update local state
                if let index = enquiries.firstIndex(where: { $0.id == id }) {
                    let original = enquiries[index]
                    enquiries[index] = Enquiry(
                        id: original.id,
                        customerName: original.customerName,
                        customerEmail: original.customerEmail,
                        customerPhone: original.customerPhone,
                        deviceType: original.deviceType,
                        deviceBrand: original.deviceBrand,
                        deviceModel: original.deviceModel,
                        imei: original.imei,
                        issueDescription: original.issueDescription,
                        preferredContact: original.preferredContact,
                        status: original.status,
                        isRead: true,
                        replyCount: original.replyCount,
                        lastReply: original.lastReply,
                        createdAt: original.createdAt,
                        updatedAt: original.updatedAt,
                        convertedOrderId: original.convertedOrderId
                    )
                }
            } catch {
                self.error = error
            }
        }
    }

    func archive(_ id: String) {
        Task {
            do {
                let endpoint = APIEndpoint.archiveEnquiry(id: id)
                try await APIClient.shared.requestVoid(endpoint)

                // Remove from list
                enquiries.removeAll { $0.id == id }

                // Refresh stats
                await loadStats()
            } catch {
                self.error = error
            }
        }
    }
}

// MARK: - Response Types
/// Response wrapper for enquiries/tickets list endpoint
struct EnquiriesResponse: Decodable {
    let tickets: [Enquiry]
    let page: Int
    let totalPages: Int
    let total: Int
    let limit: Int

    // Computed property to match existing code expectations
    var items: [Enquiry] { tickets }
    var pagination: EnquiriesPagination {
        EnquiriesPagination(page: page, pages: totalPages, total: total, limit: limit)
    }

    struct EnquiriesPagination {
        let page: Int
        let pages: Int
        let total: Int
        let limit: Int

        var hasMore: Bool { page < pages }
    }
}
