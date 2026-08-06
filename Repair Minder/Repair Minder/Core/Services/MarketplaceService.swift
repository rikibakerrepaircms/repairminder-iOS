//
//  MarketplaceService.swift
//  Repair Minder
//
//  Thin wrappers over APIClient for the Buyback Marketplace endpoints --
//  mirrors the BuybackService pattern. See
//  worker/buyback_marketplace_dashboard_handlers.js for the backend shapes.
//

import Foundation

@MainActor
final class MarketplaceService {
    private let api: APIClient
    // APIClient.shared is @MainActor-isolated, so it cannot be a default-arg
    // value (default args are evaluated in a nonisolated context). Use
    // optional + nil-coalesce; the init body runs on the MainActor.
    init(api: APIClient? = nil) { self.api = api ?? APIClient.shared }

    // MARK: - Searches

    /// GET /api/buyback/marketplace/searches
    func listSearches() async throws -> [MarketplaceSearch] {
        let response: MarketplaceSearchesResponse = try await api.request(.marketplaceSearches)
        return response.searches
    }

    /// POST /api/buyback/marketplace/searches
    func createSearch(_ request: CreateMarketplaceSearchRequest) async throws -> MarketplaceSearch {
        let response: MarketplaceSearchResponse = try await api.request(.createMarketplaceSearch, body: request)
        return response.search
    }

    /// PATCH /api/buyback/marketplace/searches/:id
    func updateSearch(id: Int, request: UpdateMarketplaceSearchRequest) async throws -> MarketplaceSearch {
        let response: MarketplaceSearchResponse = try await api.request(.updateMarketplaceSearch(id: id), body: request)
        return response.search
    }

    /// DELETE /api/buyback/marketplace/searches/:id
    func deleteSearch(id: Int) async throws {
        try await api.requestVoid(.deleteMarketplaceSearch(id: id))
    }

    // MARK: - Listings

    /// GET /api/buyback/marketplace/listings
    func listListings(
        limit: Int = 25,
        before: String? = nil,
        beforeId: String? = nil,
        searchId: Int? = nil,
        status: String? = nil
    ) async throws -> [MarketplaceListing] {
        let response: MarketplaceListingsResponse = try await api.request(
            .marketplaceListings(limit: limit, before: before, beforeId: beforeId, searchId: searchId, status: status)
        )
        return response.listings
    }

    /// PATCH /api/buyback/marketplace/listings/:id/status
    func setListingStatus(id: String, status: String?, notes: String?) async throws -> MarketplaceListingStatus {
        struct Body: Encodable {
            let status: String?
            let notes: String?
        }
        let response: MarketplaceListingStatusResponse = try await api.request(
            .setMarketplaceListingStatus(id: id),
            body: Body(status: status, notes: notes)
        )
        return response.status
    }

    // MARK: - Blocked Sellers

    /// GET /api/buyback/marketplace/blocked-sellers
    func listBlockedSellers() async throws -> [BlockedSeller] {
        let response: BlockedSellersResponse = try await api.request(.marketplaceBlockedSellers)
        return response.blockedSellers
    }

    /// POST /api/buyback/marketplace/blocked-sellers
    func blockSeller(sellerFbId: String, sellerName: String?) async throws {
        try await api.requestVoid(.blockMarketplaceSeller, body: BlockSellerRequest(sellerFbId: sellerFbId, sellerName: sellerName))
    }

    /// DELETE /api/buyback/marketplace/blocked-sellers/:sellerFbId
    func unblockSeller(sellerFbId: String) async throws {
        try await api.requestVoid(.unblockMarketplaceSeller(sellerFbId: sellerFbId))
    }
}
