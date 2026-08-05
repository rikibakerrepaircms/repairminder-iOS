//
//  MarketplaceListing.swift
//  Repair Minder
//
//  A Facebook Marketplace buyback lead, as returned by
//  GET /api/buyback/marketplace/listings (worker/buyback_marketplace_dashboard_handlers.js,
//  handleListMarketplaceListings). Listings are a global, deduplicated table --
//  this app only ever sees listings reachable via one of the current company's
//  own searches (server-side scoped, no client-side filtering needed).
//

import Foundation

struct MarketplaceListing: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String?
    let priceFormatted: String?
    let priceAmount: String?
    let priceWasFormatted: String?
    let city: String?
    let listingURL: String
    let photoURL: String?
    let sellerName: String?
    let sellerFbId: String?
    let sellerAvatarURL: String?
    let deliveryType: String?
    let condition: String?
    let description: String?
    let fbCreatedAt: String?
    let firstSeenAt: String?
    let lastSeenAt: String?
    /// "ignored" | "contacted" | "purchased" | nil
    let status: String?
    let notes: String?

    /// Best available "when was this listed" timestamp, matching the
    /// backend's own `COALESCE(fb_created_at, first_seen_at)` sort key.
    var sortTimestamp: String? { fbCreatedAt ?? firstSeenAt }
}

/// GET /api/buyback/marketplace/listings -> { success, data: { listings: [...] } }
struct MarketplaceListingsResponse: Decodable, Sendable {
    let listings: [MarketplaceListing]
}

/// PATCH /api/buyback/marketplace/listings/:id/status -> { success, data: { status: {...} } }
struct MarketplaceListingStatusResponse: Decodable, Sendable {
    let status: MarketplaceListingStatus
}

struct MarketplaceListingStatus: Decodable, Sendable {
    let status: String?
    let notes: String?
    let updatedAt: String?
}
