//
//  CustomerOrderDetailViewModel.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import os.log

/// View model for customer order detail
@MainActor
@Observable
final class CustomerOrderDetailViewModel {
    let orderId: String

    private(set) var order: CustomerOrder?
    private(set) var timeline: [TimelineEvent] = []
    private(set) var quote: Quote?
    private(set) var isLoading = false
    private(set) var isApprovingQuote = false
    private(set) var error: String?
    private(set) var successMessage: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder-Customer", category: "CustomerOrderDetail")

    init(orderId: String) {
        self.orderId = orderId
    }

    // MARK: - Data Loading

    /// Load order details
    func loadOrder() async {
        isLoading = true
        error = nil

        do {
            // Load order details
            let orderResponse: CustomerOrderDetailResponse = try await APIClient.shared.request(
                .customerOrder(id: orderId),
                responseType: CustomerOrderDetailResponse.self
            )
            order = orderResponse.order

            // Load timeline
            await loadTimeline()

            // Load quote if awaiting approval
            if order?.status == .awaitingApproval {
                await loadQuote()
            }

            logger.debug("Loaded order \(self.orderId)")
        } catch let apiError as APIError {
            logger.error("Failed to load order: \(apiError.localizedDescription)")
            switch apiError {
            case .notFound:
                error = "Order not found."
            case .offline:
                error = "You're offline. Please try again when connected."
            default:
                error = "Failed to load order details."
            }
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            self.error = "An unexpected error occurred."
        }

        isLoading = false
    }

    /// Load order timeline
    private func loadTimeline() async {
        do {
            let response: TimelineResponse = try await APIClient.shared.request(
                .customerOrderTimeline(id: orderId),
                responseType: TimelineResponse.self
            )
            timeline = response.events
        } catch {
            logger.error("Failed to load timeline: \(error.localizedDescription)")
            // Generate default timeline from status
            timeline = generateDefaultTimeline()
        }
    }

    /// Load quote for approval
    private func loadQuote() async {
        do {
            let response: QuoteResponse = try await APIClient.shared.request(
                .customerOrderQuote(orderId: orderId),
                responseType: QuoteResponse.self
            )
            quote = response.quote
        } catch {
            logger.error("Failed to load quote: \(error.localizedDescription)")
        }
    }

    // MARK: - Quote Actions

    /// Approve the quote
    func approveQuote() async {
        isApprovingQuote = true
        error = nil
        successMessage = nil

        do {
            try await APIClient.shared.requestVoid(.customerApproveQuote(orderId: orderId))
            successMessage = "Quote approved! Your repair will begin shortly."
            logger.debug("Quote approved for order \(self.orderId)")

            // Reload order to get updated status
            await loadOrder()
        } catch {
            logger.error("Failed to approve quote: \(error.localizedDescription)")
            self.error = "Failed to approve quote. Please try again."
        }

        isApprovingQuote = false
    }

    /// Reject the quote with a reason
    func rejectQuote(reason: String) async {
        isApprovingQuote = true
        error = nil
        successMessage = nil

        do {
            try await APIClient.shared.requestVoid(.customerRejectQuote(orderId: orderId, reason: reason))
            successMessage = "Quote declined. The shop will be notified."
            logger.debug("Quote rejected for order \(self.orderId)")

            // Reload order
            await loadOrder()
        } catch {
            logger.error("Failed to reject quote: \(error.localizedDescription)")
            self.error = "Failed to decline quote. Please try again."
        }

        isApprovingQuote = false
    }

    // MARK: - Helpers

    /// Generate a default timeline based on order status
    private func generateDefaultTimeline() -> [TimelineEvent] {
        guard let order = order else { return [] }

        let allStatuses: [CustomerOrderStatus] = [
            .received, .diagnosing, .awaitingApproval, .inRepair,
            .qualityCheck, .ready, .collected
        ]

        guard let currentIndex = allStatuses.firstIndex(of: order.status) else {
            return []
        }

        return allStatuses.prefix(currentIndex + 2).enumerated().map { index, status in
            TimelineEvent(
                id: status.rawValue,
                title: status.customerDisplayName,
                description: status.customerDescription,
                date: index <= currentIndex ? (index == currentIndex ? order.updatedAt : nil) : nil,
                isCompleted: index <= currentIndex,
                isCurrent: index == currentIndex
            )
        }
    }
}

// MARK: - Response Types

struct CustomerOrderDetailResponse: Codable {
    let order: CustomerOrder
}

struct TimelineResponse: Codable {
    let events: [TimelineEvent]
}

struct QuoteResponse: Codable {
    let quote: Quote
}
