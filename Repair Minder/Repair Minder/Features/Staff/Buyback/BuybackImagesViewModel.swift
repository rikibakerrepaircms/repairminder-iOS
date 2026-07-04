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

    /// Called after any successful mutation (upload/generate/set-final/delete)
    /// so the caller can refresh anything else that embeds a smaller image
    /// preview (e.g. `BuybackDetailViewModel.refresh()`).
    var onChange: (() -> Void)?

    init(buybackId: String, service: BuybackService? = nil) {
        self.buybackId = buybackId
        self.service = service ?? BuybackService()
    }

    /// GET /api/buyback/:id/images
    func loadImages() async {
        isLoading = true
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
        isBusy = true
        imageError = nil
        defer { isBusy = false }
        do {
            _ = try await service.uploadSourceImage(id: buybackId, image: image, field: field)
            await loadImages()
            onChange?()
        } catch let e as APIError {
            imageError = e.localizedDescription
        } catch {
            imageError = error.localizedDescription
        }
    }

    /// POST /api/buyback/:id/product-photos — front-only for v1. Tier-gated:
    /// the backend may reject this (403/error) if the company lacks
    /// product-photo config; `APIError.localizedDescription` already carries
    /// the server-provided message via `serverError`/`forbidden`.
    func generate(front: PlatformImageData, imageType: String? = nil) async {
        isBusy = true
        imageError = nil
        defer { isBusy = false }
        do {
            let response = try await service.generateProductPhotos(id: buybackId, front: front, imageType: imageType)
            if (response.totalGenerated ?? response.generated?.count ?? 0) == 0,
               let errors = response.errors, !errors.isEmpty {
                imageError = errors.joined(separator: "\n")
            }
            await loadImages()
            onChange?()
        } catch let e as APIError {
            imageError = e.localizedDescription
        } catch {
            imageError = error.localizedDescription
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
            onChange?()
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
            onChange?()
        } catch let e as APIError {
            imageError = e.localizedDescription
        } catch {
            imageError = error.localizedDescription
        }
    }
}
