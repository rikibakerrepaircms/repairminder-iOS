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

    @Published var isMutating = false
    @Published var actionError: String?

    private let buybackId: String
    private let service = BuybackService()

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

    // MARK: - Lifecycle Mutations (Phase 3)

    /// PATCH /api/buyback/:id/status — moves the device to a new lifecycle status.
    /// Returns true on success.
    func changeStatus(to status: String) async -> Bool {
        isMutating = true
        actionError = nil
        defer { isMutating = false }
        do {
            _ = try await service.updateStatus(id: buybackId, status: status)
            await loadDetail()
            return true
        } catch let e as APIError {
            actionError = e.localizedDescription
            return false
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    /// PATCH /api/buyback/:id — used for purchase-info edits and other field patches.
    /// Returns true on success.
    func updatePurchase(fields: [String: AnyEncodable]) async -> Bool {
        isMutating = true
        actionError = nil
        defer { isMutating = false }
        do {
            try await service.updateFields(id: buybackId, fields: fields)
            await loadDetail()
            return true
        } catch let e as APIError {
            actionError = e.localizedDescription
            return false
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    /// POST /api/buyback/:id/notes — returns nil on success, an error message otherwise.
    func addNote(_ text: String) async -> String? {
        isMutating = true
        actionError = nil
        defer { isMutating = false }
        do {
            _ = try await service.addNote(id: buybackId, body: text)
            await loadDetail()
            return nil
        } catch let e as APIError {
            return e.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    /// POST /api/buyback/:id/sell — returns nil on success, an error message otherwise.
    func sell(_ request: SellBuybackRequest) async -> String? {
        isMutating = true
        actionError = nil
        defer { isMutating = false }
        do {
            _ = try await service.sell(id: buybackId, request: request)
            await loadDetail()
            return nil
        } catch let e as APIError {
            return e.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    /// PATCH /api/buyback/:id — toggles storefront publication. Returns true on success.
    /// The backend rejects publishing while Find My / iCloud checks are not clear.
    func setPublished(_ published: Bool) async -> Bool {
        isMutating = true
        actionError = nil
        defer { isMutating = false }
        do {
            try await service.updateFields(id: buybackId, fields: ["storefront_published": AnyEncodable(published)])
            await loadDetail()
            return true
        } catch let e as APIError {
            actionError = e.localizedDescription
            return false
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }
}
