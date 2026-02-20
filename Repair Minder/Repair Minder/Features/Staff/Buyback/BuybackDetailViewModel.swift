//
//  BuybackDetailViewModel.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import Foundation

@MainActor
final class BuybackDetailViewModel: ObservableObject {
    @Published private(set) var buyback: BuybackDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let buybackId: String

    init(buybackId: String) {
        self.buybackId = buybackId
    }

    func loadDetail() async {
        isLoading = true
        error = nil

        do {
            let url = URL(string: "https://api.repairminder.com/api/buyback/\(buybackId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            guard let token = AuthManager.shared.accessToken else {
                throw URLError(.userAuthenticationRequired)
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            struct Envelope: Decodable {
                let success: Bool
                let data: BuybackDetail
            }

            let envelope = try decoder.decode(Envelope.self, from: data)
            buyback = envelope.data
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadDetail()
    }
}
