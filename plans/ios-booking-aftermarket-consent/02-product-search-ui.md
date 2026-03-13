# Stage 02: Product Search + Tier Selection UI

## Objective

Create three reusable SwiftUI components for product search, tier selection, and line item display during booking.

## Dependencies

[Requires: Stage 01 complete] — `BookingLineItem`, `ProductComponentsResponse`, `QualityTier`, `.productComponents` endpoint.

## Complexity

Medium

## Files to Create

| File | Purpose |
|------|---------|
| `Repair Minder/Repair Minder/Features/Staff/Booking/Components/BookingProductSearch.swift` | Search-as-you-type product lookup with tier-aware selection |
| `Repair Minder/Repair Minder/Features/Staff/Booking/Components/TierSelectionSheet.swift` | Half-sheet for choosing quality tier (Aftermarket/Premium/etc.) |
| `Repair Minder/Repair Minder/Features/Staff/Booking/Components/DeviceLineItemsList.swift` | Per-device list of added line items with add/remove and subtotal |

**Remember to add all 3 new files to the Xcode project (both iOS and Mac targets).**

## Implementation Details

### 1. BookingProductSearch.swift

Reuse the pattern from `OrderItemFormSheet.swift` (lines 274–371) — debounced search calling `.productTypes(search:)`.

```swift
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
```

### 2. TierSelectionSheet.swift

Half-sheet presenting tier options with names and prices.

```swift
//
//  TierSelectionSheet.swift
//  Repair Minder
//

import SwiftUI

struct TierSelectionSheet: View {
    let productName: String
    let defaultPrice: Double
    let tiers: [QualityTier]
    let onSelect: (_ tierName: String?, _ price: Double) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tiers) { tier in
                        Button {
                            dismiss()
                            onSelect(tier.tier, tier.price ?? defaultPrice)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tier.tier)
                                        .font(.headline)
                                    // Visual hint for aftermarket
                                    if tier.tier.lowercased().contains("aftermarket") {
                                        Text("Third-party component")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Text(CurrencyFormatter.format(tier.price ?? defaultPrice))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Select quality tier")
                }

                Section {
                    Button {
                        dismiss()
                        onSelect(nil, defaultPrice)
                    } label: {
                        HStack {
                            Text("Use default (no tier)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CurrencyFormatter.format(defaultPrice))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(productName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onCancel()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
```

### 3. DeviceLineItemsList.swift

Inline list of line items with add/remove. Embedded in device cards on the Summary step.

```swift
//
//  DeviceLineItemsList.swift
//  Repair Minder
//

import SwiftUI

struct DeviceLineItemsList: View {
    @Binding var items: [BookingLineItem]
    let currencyCode: String

    @State private var showSearch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label("Services / Parts", systemImage: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    showSearch.toggle()
                } label: {
                    Label("Add Service", systemImage: "plus")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            // Search (expandable)
            if showSearch {
                BookingProductSearch(
                    onSelect: { item in
                        items.append(item)
                        showSearch = false
                    },
                    onCancel: { showSearch = false }
                )
            }

            // Line items list
            if !items.isEmpty {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            Text(item.description)
                                .font(.subheadline)
                                .lineLimit(1)

                            Spacer()

                            Text(CurrencyFormatter.format(item.unitPrice))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Button {
                                items.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.platformBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Subtotal
                    HStack {
                        Spacer()
                        Text("Subtotal:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(
                            items.reduce(0) { $0 + $1.unitPrice * Double($1.quantity) }
                        ))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.top, 8)
    }
}
```

## Database Changes

None.

## Test Cases

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Type 2 chars in product search | Debounced API call, results appear |
| 2 | Type 1 char | No search triggered |
| 3 | Select product with no tiers | Item added directly, no tier sheet |
| 4 | Select service product with tiers | Tier sheet appears with options |
| 5 | Select "Aftermarket" tier | Item added with `qualityTier = "Aftermarket"` and tier price |
| 6 | Select "Use default (no tier)" | Item added with empty qualityTier and default price |
| 7 | Cancel tier sheet | No item added, returns to search |
| 8 | Remove a line item | Item removed, subtotal updates |
| 9 | Add 3 items | All shown with correct subtotal |
| 10 | iPad layout | Components render cleanly in regular size class |

## Acceptance Checklist

- [ ] `BookingProductSearch.swift` created with debounced search, tier detection, item creation
- [ ] `TierSelectionSheet.swift` created with tier options, default option, cancel
- [ ] `DeviceLineItemsList.swift` created with add/remove items, subtotal
- [ ] All 3 files added to Xcode project (iOS + Mac targets)
- [ ] All 3 targets build clean (`Cmd+B`)
- [ ] Product search returns results (verify in Xcode preview or simulator)
- [ ] Tier sheet presents as half-sheet on iOS

## Deployment

No deployment needed — UI components only, not yet wired into the booking flow.

Build verification:
```
Open Xcode → Select each scheme (iOS, Mac) → Cmd+B
```

## Handoff Notes

- These 3 components are used in Stage 03 when they get embedded in `SummaryStepView`
- `DeviceLineItemsList` takes a `@Binding var items: [BookingLineItem]` — the binding comes from the device entry in the view model
- The `BookingProductSearch` calls `APIClient.shared.request(.productTypes(search:))` which returns `[ProductTypeSearchResult]` — this is an existing endpoint, well-tested
- The `.productComponents` call is new — if it fails (e.g. product has no components), the product is added without tier selection (graceful fallback)
