//
//  MarketplaceFeedView.swift
//  Repair Minder
//
//  Root view for the Marketplace tab -- the Facebook Marketplace buyback
//  lead feed. Browsing only here; per-listing actions (status/notes/open in
//  Facebook) live in MarketplaceListingDetailView, search management in
//  MarketplaceSearchesView, blocked sellers in MarketplaceBlockedSellersView.
//

import SwiftUI

struct MarketplaceFeedView: View {
    @StateObject private var viewModel = MarketplaceFeedViewModel()
    @State private var showSearches = false
    @State private var showBlockedSellers = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            if viewModel.listings.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.listings) { listing in
                        NavigationLink {
                            MarketplaceListingDetailView(listing: listing) { updatedStatus in
                                viewModel.applyStatusUpdate(listingId: listing.id, status: updatedStatus)
                            }
                        } label: {
                            MarketplaceListingCard(listing: listing)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if listing.id == viewModel.listings.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }
                }
                .padding()

                if viewModel.isLoadingMore {
                    ProgressView().padding()
                }
            }
        }
        .navigationTitle("Marketplace")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Saved Searches") { showSearches = true }
                    Button("Blocked Sellers") { showBlockedSellers = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .navigation) {
                Picker("Show", selection: $viewModel.viewMode) {
                    ForEach(MarketplaceViewMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            }
            if viewModel.searches.count > 1 {
                ToolbarItem(placement: .navigation) {
                    Picker("Search", selection: $viewModel.selectedSearchId) {
                        Text("All searches").tag(Int?.none)
                        ForEach(viewModel.searches) { search in
                            Text(search.searchTerm).tag(Int?.some(search.id))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSearches) {
            NavigationStack { MarketplaceSearchesView() }
        }
        .sheet(isPresented: $showBlockedSellers) {
            NavigationStack { MarketplaceBlockedSellersView() }
        }
        .refreshable { await viewModel.refresh() }
        .task {
            await viewModel.loadSearches()
            await viewModel.refresh()
        }
        .onChange(of: viewModel.selectedSearchId) { _, _ in
            Task { await viewModel.refresh() }
        }
        .onChange(of: viewModel.viewMode) { _, _ in
            Task { await viewModel.refresh() }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(viewModel.isLoading ? "Loading..." : "No listings yet")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

/// One card in the marketplace feed grid.
private struct MarketplaceListingCard: View {
    let listing: MarketplaceListing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: listing.photoUrl.flatMap(URL.init(string:))) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.15)
                }
                .frame(height: 140)
                .clipped()

                if let name = listing.sellerName {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title ?? "Untitled listing")
                    .font(.caption).fontWeight(.semibold)
                    .lineLimit(2)
                Text(listing.city ?? "Unknown location")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(listing.priceFormatted ?? "No price")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(.blue)
                    if let wasPrice = listing.priceWasFormatted {
                        Text(wasPrice)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                    }
                    Spacer()
                    if let status = listing.status {
                        Text(status.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.blue.opacity(0.15), in: Capsule())
                    }
                }
            }
            .padding(8)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator))
    }
}
