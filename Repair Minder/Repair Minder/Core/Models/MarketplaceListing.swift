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
    /// Most-recent price-drop timestamp (nullable -- no drop observed since
    /// tracking began).
    let priceReducedAt: String?
    let city: String?
    let listingUrl: String
    let photoUrl: String?
    let sellerName: String?
    let sellerFbId: String?
    let sellerAvatarUrl: String?
    let deliveryType: String?
    let condition: String?
    let description: String?
    let fbCreatedAt: String?
    let firstSeenAt: String?
    let lastSeenAt: String?
    /// "ignored" | "contacted" | "purchased" | nil
    let status: String?
    let notes: String?
    /// The Worker's own `COALESCE(fb_created_at, MIN(first_seen_at))` sort/cursor
    /// key, returned directly on the response since the pagination-cursor fix
    /// (round 1, item 4). Preferred over recomputing locally so this app can't
    /// silently drift from the server's actual sort logic if it ever changes
    /// (e.g. the MIN-across-memberships part).
    let sortKey: String?

    /// Best available "when was this listed" timestamp -- prefers the
    /// server's own `sortKey`, falling back to the equivalent local
    /// computation for a response that predates that field.
    var sortTimestamp: String? { sortKey ?? fbCreatedAt ?? firstSeenAt }

    /// Abbreviated relative time since the most recent price drop (e.g. "2d"),
    /// or nil if there's no reduction to show.
    var priceReducedRelativeTime: String? {
        guard let priceReducedAt, let date = DateFormatters.parseDate(priceReducedAt) else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
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
