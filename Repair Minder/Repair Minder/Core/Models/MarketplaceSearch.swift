//
//  MarketplaceSearch.swift
//  Repair Minder
//
//  A company's saved Facebook Marketplace search (term + location + radius),
//  as returned by GET /api/buyback/marketplace/searches
//  (worker/buyback_marketplace_dashboard_handlers.js). `enabled` arrives from
//  D1 as INTEGER 0/1, hence FlexibleBool -- see Core/Networking/FlexibleDecoding.swift.
//

import Foundation

struct MarketplaceSearch: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let searchTerm: String
    let locationLabel: String
    let fbLocationId: String
    let radiusKm: Int
    let pollIntervalMinutes: Int
    let enabled: FlexibleBool
    let lastPolledAt: String?

    var isEnabled: Bool { enabled.value }
}

/// GET /api/buyback/marketplace/searches -> { success, data: { searches: [...] } }
struct MarketplaceSearchesResponse: Decodable, Sendable {
    let searches: [MarketplaceSearch]
}

/// POST /api/buyback/marketplace/searches -> { success, data: { search: {...} } }
/// PATCH /api/buyback/marketplace/searches/:id -> { success, data: { search: {...} } }
struct MarketplaceSearchResponse: Decodable, Sendable {
    let search: MarketplaceSearch
}

/// Request body for POST /api/buyback/marketplace/searches
struct CreateMarketplaceSearchRequest: Encodable {
    let searchTerm: String
    let locationLabel: String
    let fbLocationId: String
    let radiusKm: Int
    let pollIntervalMinutes: Int
}

/// Request body for PATCH /api/buyback/marketplace/searches/:id -- only
/// non-nil fields are sent (mirrors the worker's partial-update handling).
struct UpdateMarketplaceSearchRequest: Encodable {
    var searchTerm: String?
    var locationLabel: String?
    var fbLocationId: String?
    var radiusKm: Int?
    var pollIntervalMinutes: Int?
    var enabled: Bool?
}
