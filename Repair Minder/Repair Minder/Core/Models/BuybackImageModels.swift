//
//  BuybackImageModels.swift
//  Repair Minder
//
//  Package D — buyback image management. Distinct from the lightweight
//  `BuybackImage` used inline on `BuybackDetail` (id/imageType/caption/
//  uploadedByName/uploadedAt only, no `is_final`/`url`); this richer model
//  backs the dedicated GET /api/buyback/:id/images management endpoint.
//

import Foundation

/// A single image as returned by GET /api/buyback/:id/images.
/// `is_final` arrives from D1 as either a real JSON bool or 0/1 — `FlexibleBool`
/// tolerates both (see `Core/Networking/FlexibleDecoding.swift`).
struct BuybackImageItem: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let imageType: String?
    let caption: String?
    let url: String?
    let uploadedBy: String?
    let uploadedAt: String?
    let isFinal: FlexibleBool?

    var isFinalValue: Bool { isFinal?.value ?? false }
}

/// POST /api/buyback/:id/source-images → { success, data: { saved: [...] } }
struct SourceImagesResponse: Decodable, Sendable {
    let saved: [BuybackImageItem]?
}

/// A single AI-generated product photo, as returned inside `generated: [...]`.
struct GeneratedPhoto: Decodable, Identifiable, Sendable {
    let id: String
    let type: String?
    let label: String?
    let url: String?
    let generatedAt: String?
}

/// POST /api/buyback/:id/product-photos → { success, data: { generated: [...],
/// errors?, total_generated, total_requested } }. Tier-gated — the backend may
/// respond with an error/403 if the company lacks product-photo config; callers
/// surface `APIError.localizedDescription` in that case rather than this shape.
struct ProductPhotosResponse: Decodable, Sendable {
    let generated: [GeneratedPhoto]?
    let errors: [String]?
    let totalGenerated: Int?
    let totalRequested: Int?
}

/// POST /api/buyback/images/:id/final → { success, data: { id, is_final: true } }
struct SetFinalResponse: Decodable, Sendable {
    let id: String
    let isFinal: FlexibleBool?
}
