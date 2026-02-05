//
//  OrderDetailViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

@MainActor
final class OrderDetailViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var order: Order?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: - Private

    private let orderId: String
    private let apiClient: APIClient

    // MARK: - Initialization

    init(orderId: String, apiClient: APIClient? = nil) {
        self.orderId = orderId
        self.apiClient = apiClient ?? APIClient.shared
    }

    // MARK: - Public Methods

    /// Load order details
    func loadOrder() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let order = try await fetchOrder()
            self.order = order
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Refresh order details
    func refresh() async {
        do {
            let order = try await fetchOrder()
            self.order = order
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private Methods

    private func fetchOrder() async throws -> Order {
        let url = URL(string: "https://api.repairminder.com/api/orders/\(orderId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = apiClient.tokenProvider?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: nil)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let apiResponse = try decoder.decode(OrderDetailAPIResponse.self, from: data)

        guard apiResponse.success, let order = apiResponse.data else {
            throw APIError.serverError(message: apiResponse.error ?? "Unknown error", code: nil)
        }

        return order
    }
}

// MARK: - API Response Type

private struct OrderDetailAPIResponse: Decodable {
    let success: Bool
    let data: Order?
    let error: String?
}
