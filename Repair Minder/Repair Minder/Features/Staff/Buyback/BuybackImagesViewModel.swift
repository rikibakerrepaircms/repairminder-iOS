//
//  BuybackImagesViewModel.swift
//  Repair Minder
//
//  Package D — buyback image management (source upload, AI product photo
//  generation, gallery set-final/delete). Mirrors the mutation pattern used
//  by BuybackDetailViewModel (isMutating/actionError → isBusy/imageError).
//
//  Upload/generate methods accept an already-encoded `PlatformImageData`, so
//  they compile and run on both iOS and macOS even though only iOS ships a
//  picker UI to produce that payload (camera/PhotosPicker are #if os(iOS)).
//

import Foundation

@MainActor
final class BuybackImagesViewModel: ObservableObject {
    @Published private(set) var images: [BuybackImageItem] = []
    @Published private(set) var isLoading = false
    @Published var isBusy = false
    @Published var imageError: String?

    let buybackId: String
    private let service: BuybackService

    init(buybackId: String, service: BuybackService? = nil) {
        self.buybackId = buybackId
        self.service = service ?? BuybackService()
    }

    /// GET /api/buyback/:id/images
    func loadImages() async {
        isLoading = true
        imageError = nil
        defer { isLoading = false }
        do {
            images = try await service.fetchImages(id: buybackId)
        } catch let e as APIError {
            imageError = e.localizedDescription
        } catch {
            imageError = error.localizedDescription
        }
    }

    /// POST /api/buyback/:id/source-images — `field` is "source_front" or
    /// "source_back"; each is a separate request (single-file multipart helper).
    func uploadSource(_ image: PlatformImageData, field: String) async {
        guard !isBusy else { return }
        isBusy = true
        imageError = nil
        defer { isBusy = false }
        do {
            _ = try await service.uploadSourceImage(id: buybackId, image: image, field: field)
            await loadImages()
        } catch let e as APIError {
            imageError = cleanMessage(e)
        } catch {
            imageError = cleanMessage(error)
        }
    }

    /// POST /api/buyback/:id/product-photos — front-only for v1. Tier-gated:
    /// the backend may reject this (403/error) if the company lacks
    /// product-photo config. That arrives as `APIError.httpError(statusCode:,
    /// message:)` with the RAW JSON response body (this goes through
    /// `uploadMultipartFull`, not `request`) — `cleanMessage` extracts the
    /// `error` field so the UI doesn't show raw JSON.
    func generate(front: PlatformImageData, imageType: String? = nil) async {
        guard !isBusy else { return }
        isBusy = true
        imageError = nil
        defer { isBusy = false }
        do {
            let response = try await service.generateProductPhotos(id: buybackId, front: front, imageType: imageType)
            let payload = response.data
            if (payload?.totalGenerated ?? payload?.generated?.count ?? 0) == 0,
               let errors = payload?.errors, !errors.isEmpty {
                imageError = errors.compactMap { $0.error }.joined(separator: "\n")
            }
            await loadImages()
        } catch let e as APIError {
            imageError = cleanMessage(e)
        } catch {
            imageError = cleanMessage(error)
        }
    }

    /// POST /api/buyback/images/:imageId/final
    func setFinal(imageId: String) async {
        isBusy = true
        imageError = nil
        defer { isBusy = false }
        do {
            _ = try await service.setImageFinal(imageId: imageId)
            await loadImages()
        } catch let e as APIError {
            imageError = e.localizedDescription
        } catch {
            imageError = error.localizedDescription
        }
    }

    /// DELETE /api/buyback/images/:imageId
    func deleteImage(imageId: String) async {
        isBusy = true
        imageError = nil
        defer { isBusy = false }
        do {
            try await service.deleteImage(imageId: imageId)
            images.removeAll { $0.id == imageId }
        } catch let e as APIError {
            imageError = e.localizedDescription
        } catch {
            imageError = error.localizedDescription
        }
    }

    /// `uploadMultipartFull` surfaces non-2xx responses as `APIError.httpError`
    /// carrying the RAW response body (e.g. `{"success":false,"error":"…"}`),
    /// unlike `.forbidden`/`.serverError` which already carry a parsed message.
    /// Extract the `error` field so tier-gate failures don't dump raw JSON in
    /// front of the user.
    private func cleanMessage(_ error: Error) -> String {
        let raw = error.localizedDescription
        if let start = raw.firstIndex(of: "{"),
           let data = String(raw[start...]).data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg = obj["error"] as? String {
            return msg
        }
        return raw
    }
}
