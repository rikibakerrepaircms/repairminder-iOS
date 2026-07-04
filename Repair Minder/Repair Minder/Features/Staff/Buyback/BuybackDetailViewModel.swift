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

    @Published var isGeneratingListing = false
    @Published var listingError: String?

    private let buybackId: String
    private let service = BuybackService()
    private var listingTask: Task<Void, Never>?

    init(buybackId: String) {
        self.buybackId = buybackId
    }

    deinit {
        listingTask?.cancel()
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
            try await service.updateFields(id: buybackId, fields: ["storefront_published": AnyEncodable(published ? 1 : 0)])
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

    // MARK: - Refurbishment Items

    /// POST /api/buyback/:id/refurbishment — returns nil on success, an error message otherwise.
    func addRefurbishment(_ request: AddRefurbishmentRequest) async -> String? {
        isMutating = true
        actionError = nil
        defer { isMutating = false }
        do {
            _ = try await service.addRefurbishment(id: buybackId, request: request)
            await loadDetail()
            return nil
        } catch let e as APIError {
            return e.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    /// PATCH /api/buyback/:id/refurbishment/:itemId — returns nil on success, an error message otherwise.
    func updateRefurbishment(itemId: String, _ request: UpdateRefurbishmentRequest) async -> String? {
        isMutating = true
        actionError = nil
        defer { isMutating = false }
        do {
            try await service.updateRefurbishment(id: buybackId, itemId: itemId, request: request)
            await loadDetail()
            return nil
        } catch let e as APIError {
            return e.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    /// DELETE /api/buyback/:id/refurbishment/:itemId — returns true on success.
    func deleteRefurbishment(itemId: String) async -> Bool {
        isMutating = true
        actionError = nil
        defer { isMutating = false }
        do {
            try await service.deleteRefurbishment(id: buybackId, itemId: itemId)
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

    // MARK: - AI Listing Generation

    /// Kicks off (or resumes visibility into) an async AI listing-generation job,
    /// then polls GET /api/buyback/:id/generate-listing every ~2s until it reaches
    /// a terminal state. On `"done"` the buyback is refetched so the newly
    /// persisted listing fields show up; on `"error"` `listingError` is set to the
    /// server-provided message. The 400 gate errors from the start call (missing
    /// fields / activation-lock block) surface via `APIError.localizedDescription`,
    /// which already contains the full "missing required field(s): ..." text.
    ///
    /// Cancellation: the caller wraps this in an owned, cancellable `Task` via
    /// `beginListingGeneration()`/`cancelListingGeneration()` (see
    /// `BuybackDetailView`). If that Task is cancelled or the view model is
    /// deallocated, `Task.sleep` throws `CancellationError` and the loop simply
    /// stops — no explicit cleanup needed since there is no persistent timer/handle.
    func generateListing() async {
        guard !isGeneratingListing else { return }
        isGeneratingListing = true
        listingError = nil
        defer { isGeneratingListing = false }
        do {
            _ = try await service.startListingGeneration(id: buybackId) // 202 or 200 (already_running)

            let deadline = 180 // client-side cap; server also auto-fails a job after 15 min
            var elapsed = 0
            while elapsed < deadline {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                elapsed += 2

                let state = try await service.listingStatus(id: buybackId)
                switch ListingJobStatus(rawValue: state.status) {
                case .done:
                    await loadDetail()
                    return
                case .error:
                    listingError = state.error ?? "Listing generation failed."
                    return
                case .running, .idle, .none:
                    // Unknown/unmapped values keep polling too, bounded by the deadline above.
                    continue
                }
            }
            listingError = "Still generating — check back shortly."
        } catch is CancellationError {
            // Task was cancelled (e.g. view dismissed) — nothing to report.
        } catch let e as APIError {
            listingError = e.localizedDescription
        } catch {
            listingError = error.localizedDescription
        }
    }

    /// Owns an unstructured `Task` for `generateListing()` so it can be cancelled
    /// when the view disappears (otherwise the poll loop keeps running for up to
    /// 3 minutes after navigating away). `[weak self]` avoids the Task retaining
    /// this view model.
    func beginListingGeneration() {
        listingTask?.cancel()
        listingTask = Task { [weak self] in
            await self?.generateListing()
        }
    }

    /// Cancels any in-flight listing-generation poll loop (e.g. on view disappear).
    func cancelListingGeneration() {
        listingTask?.cancel()
        listingTask = nil
    }

    /// PATCH /api/buyback/:id — edits listing fields (title/description/price/condition).
    /// Returns true on success.
    func updateListing(fields: [String: AnyEncodable]) async -> Bool {
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
}
