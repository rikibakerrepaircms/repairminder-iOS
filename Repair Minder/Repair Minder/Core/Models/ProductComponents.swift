//
//  ProductComponents.swift
//  Repair Minder
//

import Foundation

/// Response from GET /api/product-types/:id/components
/// Only decodes the fields needed for tier selection during booking.
struct ProductComponentsResponse: Decodable {
    let qualityTiers: [QualityTier]
}

/// A quality tier option for a service product (e.g. "Aftermarket", "Premium")
struct QualityTier: Decodable, Identifiable {
    let tier: String
    let price: Double?

    var id: String { tier }
}
