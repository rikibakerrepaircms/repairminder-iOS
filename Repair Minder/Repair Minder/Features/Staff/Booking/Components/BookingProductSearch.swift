//
//  BookingProductSearch.swift
//  Repair Minder
//

import SwiftUI
import os.log

struct BookingProductSearch: View {
    let onSelect: (BookingLineItem) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @State private var searchResults: [ProductTypeSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    // Tier selection
    @State private var showTierSheet = false
    @State private var selectedProduct: ProductTypeSearchResult?
    @State private var availableTiers: [QualityTier] = []

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "BookingProductSearch")

    var body: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search services or parts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button { searchText = ""; searchResults = [] } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("Cancel", action: onCancel)
                    .font(.subheadline)
            }
            .padding(10)
            .background(Color.platformBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Results
            if isSearching {
                ProgressView()
                    .padding(.vertical, 8)
            }

            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchResults) { product in
                        Button {
                            handleProductSelect(product)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    if let sku = product.sku {
                                        Text(sku)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if let price = product.formattedPrice {
                                    Text(price)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if product.id != searchResults.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .onChange(of: searchText) { _, newValue in
            debounceSearch(query: newValue)
        }
        .sheet(isPresented: $showTierSheet) {
            if let product = selectedProduct {
                TierSelectionSheet(
                    productName: product.name,
                    defaultPrice: product.defaultSellPrice ?? 0,
                    tiers: availableTiers,
                    onSelect: { tierName, price in
                        let item = BookingLineItem(
                            id: UUID(),
                            productTypeId: product.id,
                            description: tierName != nil ? "\(product.name) (\(tierName!))" : product.name,
                            quantity: 1,
                            unitPrice: price,
                            vatRate: product.vatRate ?? 20,
                            itemType: product.category?.lowercased() == "accessory" ? "accessory" : "repair",
                            qualityTier: tierName ?? ""
                        )
                        onSelect(item)
                    },
                    onCancel: {
                        showTierSheet = false
                        selectedProduct = nil
                    }
                )
            }
        }
    }

    // MARK: - Search Logic

    private func debounceSearch(query: String) {
        searchTask?.cancel()
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }

            isSearching = true
            defer { isSearching = false }

            do {
                let results: [ProductTypeSearchResult] = try await APIClient.shared.request(
                    .productTypes(search: query)
                )
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch {
                logger.error("Product search failed: \(error)")
                if !Task.isCancelled {
                    searchResults = []
                }
            }
        }
    }

    private func handleProductSelect(_ product: ProductTypeSearchResult) {
        // Check for quality tiers (service products may have Aftermarket/Premium options)
        Task {
            do {
                let response: ProductComponentsResponse = try await APIClient.shared.request(
                    .productComponents(productTypeId: product.id)
                )
                if !response.qualityTiers.isEmpty {
                    selectedProduct = product
                    availableTiers = response.qualityTiers
                    showTierSheet = true
                    return
                }
            } catch {
                // No tiers or endpoint error — proceed without tier selection
                logger.debug("No tiers for \(product.id): \(error)")
            }

            // No tiers — add directly
            let item = BookingLineItem(
                id: UUID(),
                productTypeId: product.id,
                description: product.name,
                quantity: 1,
                unitPrice: product.defaultSellPrice ?? 0,
                vatRate: product.vatRate ?? 20,
                itemType: product.category?.lowercased() == "accessory" ? "accessory" : "repair",
                qualityTier: ""
            )
            onSelect(item)
        }
    }
}
