//
//  BuybackService.swift
//  Repair Minder
//
//  Buyback lifecycle write actions (Phase 3): status transitions, notes,
//  selling, and adding a scanned device into the buyback pipeline. Mirrors
//  the pattern used by InventoryService — thin wrappers over APIClient.
//

import Foundation

@MainActor
final class BuybackService {
    private let api: APIClient
    // APIClient.shared is @MainActor-isolated, so it cannot be a default-arg
    // value (default args are evaluated in a nonisolated context). Use
    // optional + nil-coalesce; the init body runs on the MainActor.
    init(api: APIClient? = nil) { self.api = api ?? APIClient.shared }

    /// PATCH /api/buyback/:id/status
    func updateStatus(id: String, status: String) async throws -> BuybackStatusResponse {
        try await api.request(.updateBuybackStatus(id: id), body: BuybackStatusRequest(status: status))
    }

    /// PATCH /api/buyback/:id — generic field patch, reused for purchase/listing edits.
    func updateFields(id: String, fields: [String: AnyEncodable]) async throws {
        try await api.requestVoid(.updateBuyback(buybackId: id), body: fields)
    }

    /// POST /api/buyback/:id/notes
    func addNote(id: String, body: String) async throws -> BuybackNote {
        try await api.request(.addBuybackNote(id: id), body: AddBuybackNoteRequest(body: body))
    }

    /// POST /api/buyback/:id/sell
    func sell(id: String, request: SellBuybackRequest) async throws -> SellBuybackResponse {
        try await api.request(.sellBuyback(id: id), body: request)
    }

    /// POST /api/buyback/sell-bulk — sell up to 20 `for_sale` items together in one order.
    func sellBulk(_ request: BulkSellRequest) async throws -> BulkSellResponse {
        try await api.request(.sellBuybackBulk, body: request)
    }

    /// POST /api/devices/:deviceId/add-to-buyback
    func addDeviceToBuyback(deviceId: String) async throws -> AddToBuybackResponse {
        try await api.request(.addDeviceToBuyback(deviceId: deviceId))
    }

    // MARK: - Refurbishment Items

    /// POST /api/buyback/:id/refurbishment
    func addRefurbishment(id: String, request: AddRefurbishmentRequest) async throws -> RefurbishmentMutationResponse {
        try await api.request(.addRefurbishmentItem(id: id), body: request)
    }

    /// PATCH /api/buyback/:id/refurbishment/:itemId
    func updateRefurbishment(id: String, itemId: String, request: UpdateRefurbishmentRequest) async throws {
        try await api.requestVoid(.updateRefurbishmentItem(id: id, itemId: itemId), body: request)
    }

    /// DELETE /api/buyback/:id/refurbishment/:itemId
    func deleteRefurbishment(id: String, itemId: String) async throws {
        try await api.requestVoid(.deleteRefurbishmentItem(id: id, itemId: itemId))
    }

    // MARK: - AI Listing Generation

    /// POST /api/buyback/:id/generate-listing — starts an async listing-generation
    /// job (202), or reports the already-running job (200).
    func startListingGeneration(id: String) async throws -> ListingJobStart {
        try await api.request(.generateBuybackListing(id: id))
    }

    /// GET /api/buyback/:id/generate-listing — current job state (always 200).
    func listingStatus(id: String) async throws -> ListingJobState {
        try await api.request(.buybackListingStatus(id: id))
    }

    // MARK: - Image Management (Package D)

    /// GET /api/buyback/:id/images — optionally filtered by `image_type`.
    func fetchImages(id: String, imageType: String? = nil) async throws -> [BuybackImageItem] {
        try await api.request(.buybackImages(id: id, imageType: imageType))
    }

    /// POST /api/buyback/:id/source-images — one multipart request per photo.
    /// The backend accepts `source_front` / `source_back` fields (each needs
    /// >=1); `uploadMultipartFull` is single-file only, so front and back are
    /// sent as two separate requests using `field` to pick which name to use.
    func uploadSourceImage(id: String, image: PlatformImageData, field: String) async throws -> SourceImagesResponse {
        try await api.uploadMultipartFull(
            .uploadBuybackSourceImage(id: id),
            fileData: image.jpegData,
            fileName: image.fileName,
            mimeType: "image/jpeg",
            fileFieldName: field,
            fields: [:]
        )
    }

    /// POST /api/buyback/:id/product-photos — front-only for v1 (single-file
    /// multipart helper can't attach a second `source_back` in the same request).
    /// Tier-gated: a non-2xx here typically means the company lacks product-photo
    /// config. This goes through `uploadMultipartFull`, so a non-2xx arrives as
    /// `APIError.httpError(statusCode:, message:)` with the RAW response body
    /// string (not `.forbidden`/`.serverError`, which carry a pre-parsed message).
    /// Callers must parse the JSON out of that raw body before showing it to the
    /// user — see `BuybackImagesViewModel.cleanMessage(_:)`.
    func generateProductPhotos(id: String, front: PlatformImageData, imageType: String? = nil) async throws -> ProductPhotosResponse {
        try await api.uploadMultipartFull(
            .generateBuybackProductPhotos(id: id),
            fileData: front.jpegData,
            fileName: front.fileName,
            mimeType: "image/jpeg",
            fileFieldName: "source_front",
            fields: imageType.map { ["image_type": $0] } ?? [:]
        )
    }

    /// POST /api/buyback/images/:imageId/final — bodyless.
    func setImageFinal(imageId: String) async throws -> SetFinalResponse {
        try await api.request(.setBuybackImageFinal(imageId: imageId))
    }

    /// DELETE /api/buyback/images/:imageId → { success, message } with NO `data`
    /// key. `requestVoid` decodes `APIResponse<EmptyResponse>`, whose `data` field
    /// is Optional — Swift's synthesized decoding maps a missing key to `nil` for
    /// Optional properties, and the check inside `requestVoid` only inspects
    /// `response.success` (never unwraps `data`), so this decodes cleanly without
    /// any custom handling. Verified by reading `APIResponse<T>` / `requestVoid`.
    func deleteImage(imageId: String) async throws {
        try await api.requestVoid(.deleteBuybackImage(imageId: imageId))
    }
}
