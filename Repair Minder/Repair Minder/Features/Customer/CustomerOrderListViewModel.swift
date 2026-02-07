//
//  CustomerOrderListViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI

/// ViewModel for customer order list
@MainActor
final class CustomerOrderListViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var orders: [CustomerOrderSummary] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var currencyCode: String = "GBP"

    // MARK: - Dependencies

    private let customerAuth = CustomerAuthManager.shared

    // MARK: - Initialization

    init() {}

    // MARK: - Data Loading

    /// Load customer orders from API
    func loadOrders() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await fetchOrders()
            orders = response.orders
            currencyCode = response.currencyCode
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[CustomerOrderListVM] Error loading orders: \(error)")
            #endif
        } catch {
            errorMessage = "Failed to load orders"
            #if DEBUG
            print("[CustomerOrderListVM] Unexpected error: \(error)")
            #endif
        }

        isLoading = false
    }

    /// Refresh orders (for pull-to-refresh)
    func refresh() async {
        await loadOrders()
    }

    // MARK: - Private API Methods

    private func fetchOrders() async throws -> (orders: [CustomerOrderSummary], currencyCode: String) {
        guard let token = customerAuth.accessToken else {
            throw APIError.unauthorized
        }

        let url = URL(string: "https://api.repairminder.com/api/customer/orders")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        // Parse the response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Note: dates are decoded manually in CustomerOrderSummary.init(from:)

        let apiResponse = try decoder.decode(CustomerOrdersAPIResponse.self, from: data)

        guard apiResponse.success else {
            throw APIError.serverError(message: apiResponse.error ?? "Unknown error", code: nil)
        }

        return (apiResponse.data ?? [], apiResponse.currencyCode ?? "GBP")
    }

    // MARK: - Computed Properties

    /// Whether there are any orders
    var hasOrders: Bool {
        !orders.isEmpty
    }

    /// Orders requiring action (awaiting approval)
    var actionRequiredOrders: [CustomerOrderSummary] {
        orders.filter { $0.isAwaitingAction }
    }

    /// Active orders (in progress, not completed)
    var activeOrders: [CustomerOrderSummary] {
        orders.filter { !$0.isRejected && $0.status != "collected" && $0.status != "despatched" }
    }

    /// Completed orders
    var completedOrders: [CustomerOrderSummary] {
        orders.filter { $0.status == "collected" || $0.status == "despatched" }
    }

    // MARK: - Currency Formatting

    /// Format a decimal amount with currency symbol
    func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode

        return formatter.string(from: amount as NSDecimalNumber) ?? "£\(amount)"
    }
}

// MARK: - API Response Model

/// Custom response model for orders endpoint
private struct CustomerOrdersAPIResponse: Decodable {
    let success: Bool
    let data: [CustomerOrderSummary]?
    let currencyCode: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case data
        case currencyCode = "currency_code"
        case error
    }
}
