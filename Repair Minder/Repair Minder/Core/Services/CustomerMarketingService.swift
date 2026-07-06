//
//  CustomerMarketingService.swift
//  Repair Minder
//
//  Created on 06/07/2026.
//

import Foundation

/// Service for the customer-facing marketing self-service endpoints:
/// giveaway/competition entries, marketing consent preferences, and
/// withdrawal requests.
///
/// Builds its own `URLRequest`s with the customer bearer token rather than
/// going through `APIClient.shared`, which only carries the staff token
/// (mirrors the idiom in `CustomerOrderListViewModel.fetchOrders()`).
@MainActor
final class CustomerMarketingService {
    static let shared = CustomerMarketingService()

    private let base = "https://api.repairminder.com"
    private let auth = CustomerAuthManager.shared

    private init() {}

    private func makeRequest(_ path: String, method: String, body: [String: Any]? = nil) throws -> URLRequest {
        guard let token = auth.accessToken else { throw APIError.unauthorized }
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return req
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func send<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw APIError.unauthorized
        }
        let wrapped = try decoder().decode(APIResponse<T>.self, from: data)
        guard wrapped.success, let value = wrapped.data else {
            throw APIError.serverError(message: wrapped.error ?? "Unknown error", code: nil)
        }
        return value
    }

    private func sendVoid(_ req: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw APIError.unauthorized
        }
        // Best-effort success check; withdraw-request is intentionally generic.
        _ = data
    }

    struct EntriesData: Decodable {
        let entries: [CustomerCompetitionEntry]
    }

    /// GET /api/customer/marketing/entries
    func fetchEntries() async throws -> [CustomerCompetitionEntry] {
        let data: EntriesData = try await send(
            makeRequest("/api/customer/marketing/entries", method: "GET"),
            as: EntriesData.self
        )
        return data.entries
    }

    /// GET /api/customer/marketing/preferences
    func fetchPreferences() async throws -> CustomerMarketingPreferences {
        try await send(
            makeRequest("/api/customer/marketing/preferences", method: "GET"),
            as: CustomerMarketingPreferences.self
        )
    }

    /// PUT /api/customer/marketing/preferences
    func updatePreferences(consent: Bool) async throws -> CustomerMarketingPreferences {
        try await send(
            makeRequest(
                "/api/customer/marketing/preferences",
                method: "PUT",
                body: ["marketing_consent": consent]
            ),
            as: CustomerMarketingPreferences.self
        )
    }

    /// POST /api/customer/marketing/entries/:campaignId/withdraw-request
    func requestWithdrawal(campaignId: String) async throws {
        let path = "/api/customer/marketing/entries/\(campaignId)/withdraw-request"
        try await sendVoid(makeRequest(path, method: "POST", body: [:]))
    }
}
