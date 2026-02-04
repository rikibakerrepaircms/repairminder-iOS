//
//  ClientDetailViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import Combine

@MainActor
final class ClientDetailViewModel: ObservableObject {
    @Published var client: Client?
    @Published var orders: [Order] = []
    @Published var isLoading: Bool = true
    @Published var error: String?

    private let clientId: String
    private var currentPage = 1
    private var totalPages = 1
    private let pageSize = 20

    var hasMoreOrders: Bool {
        currentPage < totalPages
    }

    init(clientId: String) {
        self.clientId = clientId
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            // Load client details
            client = try await APIClient.shared.request(
                .client(id: clientId),
                responseType: Client.self
            )

            // Load client's order history
            currentPage = 1
            let orderResponse: [Order] = try await APIClient.shared.request(
                .clientOrders(id: clientId, page: currentPage, limit: pageSize),
                responseType: [Order].self
            )
            orders = orderResponse
            totalPages = orderResponse.count == pageSize ? currentPage + 1 : currentPage
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreOrders() async {
        guard hasMoreOrders, !isLoading else { return }

        currentPage += 1

        do {
            let orderResponse: [Order] = try await APIClient.shared.request(
                .clientOrders(id: clientId, page: currentPage, limit: pageSize),
                responseType: [Order].self
            )
            orders.append(contentsOf: orderResponse)
            totalPages = orderResponse.count == pageSize ? currentPage + 1 : currentPage
        } catch {
            currentPage -= 1
        }
    }
}
