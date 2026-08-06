//
//  MarketplaceFeedViewModel.swift
//  Repair Minder
//
//  Cursor-paginated feed of Facebook Marketplace buyback leads. Cursor
//  fields (before/beforeId) mirror the backend's own tie-breaking cursor
//  (sort_key + id) -- see handleListMarketplaceListings in
//  worker/buyback_marketplace_dashboard_handlers.js.
//

import Foundation

@MainActor
final class MarketplaceFeedViewModel: ObservableObject {
    @Published private(set) var listings: [MarketplaceListing] = []
    @Published private(set) var searches: [MarketplaceSearch] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = true
    @Published var error: String?
    @Published var selectedSearchId: Int?

    private let service: MarketplaceService
    private let pageSize = 25

    init(service: MarketplaceService? = nil) {
        self.service = service ?? MarketplaceService()
    }

    func loadSearches() async {
        do {
            searches = try await service.listSearches()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Reload the first page, discarding any existing pagination state --
    /// used on initial appearance, pull-to-refresh, and search-filter change.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        hasMore = true

        do {
            let page = try await service.listListings(limit: pageSize, searchId: selectedSearchId)
            listings = page
            hasMore = page.count == pageSize
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Load the next page using the last-loaded listing's sort timestamp/id
    /// as the cursor -- called when the list scrolls near its end.
    func loadMore() async {
        guard !isLoadingMore, hasMore, let last = listings.last, let cursor = last.sortTimestamp else { return }
        isLoadingMore = true

        do {
            let page = try await service.listListings(
                limit: pageSize, before: cursor, beforeId: last.id, searchId: selectedSearchId
            )
            listings.append(contentsOf: page)
            hasMore = page.count == pageSize
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingMore = false
    }

    /// Applies a status/notes update returned by the detail view back into
    /// this feed's in-memory list, so navigating back shows the change
    /// without a full reload.
    func applyStatusUpdate(listingId: String, status: MarketplaceListingStatus) {
        guard let index = listings.firstIndex(where: { $0.id == listingId }) else { return }
        let existing = listings[index]
        listings[index] = MarketplaceListing(
            id: existing.id, title: existing.title, priceFormatted: existing.priceFormatted,
            priceAmount: existing.priceAmount, priceWasFormatted: existing.priceWasFormatted,
            city: existing.city, listingUrl: existing.listingUrl, photoUrl: existing.photoUrl,
            sellerName: existing.sellerName, sellerFbId: existing.sellerFbId,
            sellerAvatarUrl: existing.sellerAvatarUrl, deliveryType: existing.deliveryType,
            condition: existing.condition, description: existing.description,
            fbCreatedAt: existing.fbCreatedAt, firstSeenAt: existing.firstSeenAt,
            lastSeenAt: existing.lastSeenAt, status: status.status, notes: status.notes
        )
    }
}
