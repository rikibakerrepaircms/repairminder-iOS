//
//  CustomerOrderListViewModel.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import os.log

/// View model for customer order list
@MainActor
@Observable
final class CustomerOrderListViewModel {
    private(set) var orders: [CustomerOrder] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder-Customer", category: "CustomerOrderList")

    // MARK: - Data Loading

    /// Load customer orders from API
    func loadOrders() async {
        isLoading = true
        error = nil

        do {
            let response: CustomerOrdersResponse = try await APIClient.shared.request(
                .customerOrders(),
                responseType: CustomerOrdersResponse.self
            )
            orders = response.orders
            logger.debug("Loaded \(self.orders.count) orders")
        } catch let apiError as APIError {
            logger.error("Failed to load orders: \(apiError.localizedDescription)")
            switch apiError {
            case .offline:
                error = "You're offline. Pull to refresh when connected."
            case .unauthorized:
                error = "Session expired. Please log in again."
            default:
                error = "Failed to load orders. Pull to refresh."
            }
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            self.error = "An unexpected error occurred."
        }

        isLoading = false
    }

    /// Refresh orders
    func refresh() async {
        await loadOrders()
    }
}

// MARK: - Response Types

struct CustomerOrdersResponse: Codable {
    let orders: [CustomerOrder]
    let total: Int?
    let page: Int?
    let limit: Int?
}
