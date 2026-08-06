//
//  BlockedSeller.swift
//  Repair Minder
//
//  A company-scoped blocklist entry hiding a Facebook seller's listings from
//  the marketplace feed, as returned by
//  GET /api/buyback/marketplace/blocked-sellers
//  (worker/buyback_marketplace_dashboard_handlers.js).
//

import Foundation

struct BlockedSeller: Decodable, Identifiable, Equatable, Sendable {
    var id: String { sellerFbId }
    let sellerFbId: String
    let sellerName: String?
    let blockedAt: String
}

/// GET /api/buyback/marketplace/blocked-sellers -> { success, data: { blocked_sellers: [...] } }
struct BlockedSellersResponse: Decodable, Sendable {
    let blockedSellers: [BlockedSeller]
}

/// Request body for POST /api/buyback/marketplace/blocked-sellers
struct BlockSellerRequest: Encodable {
    let sellerFbId: String
    let sellerName: String?
}
