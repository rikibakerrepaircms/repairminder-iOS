//
//  ClientDetailViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

@MainActor
final class ClientDetailViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var client: Client?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: - Private

    private let clientId: String
    private let apiClient: APIClient

    // MARK: - Initialization

    init(clientId: String, apiClient: APIClient? = nil) {
        self.clientId = clientId
        self.apiClient = apiClient ?? APIClient.shared
    }

    // MARK: - Public Methods

    /// Load client details
    func loadClient() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let client = try await fetchClient()
            self.client = client
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Refresh client details
    func refresh() async {
        do {
            let client = try await fetchClient()
            self.client = client
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private Methods

    private func fetchClient() async throws -> Client {
        let url = URL(string: "https://api.repairminder.com/api/clients/\(clientId)")!
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

        let apiResponse = try decoder.decode(ClientDetailAPIResponse.self, from: data)

        guard apiResponse.success, let client = apiResponse.data else {
            throw APIError.serverError(message: apiResponse.error ?? "Unknown error", code: nil)
        }

        return client
    }
}

// MARK: - API Response Type

private struct ClientDetailAPIResponse: Decodable {
    let success: Bool
    let data: Client?
    let error: String?
}
