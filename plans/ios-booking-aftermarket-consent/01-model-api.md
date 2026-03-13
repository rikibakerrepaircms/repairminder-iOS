# Stage 01: Model Layer + API Endpoint

## Objective

Add all data structures and the API endpoint definition needed by subsequent stages. No UI changes.

## Dependencies

None — this is the foundation stage.

## Complexity

Low

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Repair Minder/Core/Models/BookingFormData.swift` | Add `BookingLineItem` struct, update `BookingDeviceEntry` with `lineItems` + `aftermarketConsent`, update `CreateOrderDeviceRequest`, add computed helpers |
| `Repair Minder/Repair Minder/Core/Models/Order.swift` | Add `qualityTier: String?` to `OrderItem` + `OrderItemRequest` |
| `Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift` | Add `.productComponents(productTypeId:)` endpoint |

## Files to Create

| File | Purpose |
|------|---------|
| `Repair Minder/Repair Minder/Core/Models/ProductComponents.swift` | Response models for `GET /api/product-types/:id/components` |

**Remember to add the new file to the Xcode project (both iOS and Mac targets).**

## Implementation Details

### 1. BookingFormData.swift — New `BookingLineItem` struct

Add adjacent to `BookingAccessoryItem`:

```swift
/// A service line item added to a device during booking
struct BookingLineItem: Identifiable, Equatable {
    let id: UUID
    var productTypeId: String
    var description: String
    var quantity: Int
    var unitPrice: Double       // VAT-inclusive price (matches web pattern)
    var vatRate: Double          // e.g. 20.0 for 20%
    var itemType: String         // "repair", "accessory"
    var qualityTier: String      // "" = no tier, "Aftermarket", "Premium", etc.

    static func empty() -> BookingLineItem {
        BookingLineItem(
            id: UUID(),
            productTypeId: "",
            description: "",
            quantity: 1,
            unitPrice: 0,
            vatRate: 20,
            itemType: "repair",
            qualityTier: ""
        )
    }
}
```

### 2. BookingFormData.swift — Update `BookingDeviceEntry`

Add two new properties:

```swift
var lineItems: [BookingLineItem]
var aftermarketConsent: Bool
```

Add computed helpers:

```swift
/// Whether any line item has an aftermarket quality tier
var hasAftermarketItems: Bool {
    lineItems.contains { $0.qualityTier.lowercased().contains("aftermarket") }
}

/// Sum of all line item prices (inc VAT)
var lineItemSubtotal: Double {
    lineItems.reduce(0) { $0 + $1.unitPrice * Double($1.quantity) }
}
```

Update `empty()` factory to initialise both:

```swift
lineItems: [],
aftermarketConsent: false
```

### 3. BookingFormData.swift — Update `BookingFormData`

Add computed helper:

```swift
/// Whether all devices with aftermarket items have consent
var allAftermarketConsented: Bool {
    devices.allSatisfy { !$0.hasAftermarketItems || $0.aftermarketConsent }
}
```

### 4. BookingFormData.swift — Update `CreateOrderDeviceRequest`

Add field:

```swift
let aftermarketConsent: Int?    // 0 or 1, matches backend INTEGER column
```

### 5. Order.swift — Update `OrderItem`

Add `qualityTier` to the struct, CodingKeys, and custom `init(from:)`:

```swift
// In struct properties:
let qualityTier: String?

// In CodingKeys:
case qualityTier

// In init(from:):
qualityTier = try container.decodeIfPresent(String.self, forKey: .qualityTier)
```

### 6. Order.swift — Update `OrderItemRequest`

Add field:

```swift
var qualityTier: String?
```

### 7. APIEndpoints.swift — Add endpoint

In the enum cases (Product Types section):

```swift
case productComponents(productTypeId: String)
```

In `path`:

```swift
case .productComponents(let productTypeId):
    return "/api/product-types/\(productTypeId)/components"
```

In `method` — add to the GET list:

```swift
.productComponents
```

In `requiresAuth` — default is `true`, so nothing to add.

No query parameters needed.

### 8. ProductComponents.swift — New file

```swift
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
```

The backend returns `{ success, data: { service_product, common_components, quality_tiers, all_components } }` but we only need `quality_tiers`. The APIClient wraps in `APIResponse<T>` which extracts `data`, so `T = ProductComponentsResponse` decodes `{ quality_tiers: [...] }`.

## Database Changes

None — backend already has all fields.

## Test Cases

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Build all 3 targets (iOS, iPad, Mac) | Compiles without errors |
| 2 | `BookingDeviceEntry.empty()` | Returns entry with `lineItems: []`, `aftermarketConsent: false` |
| 3 | `hasAftermarketItems` with no items | Returns `false` |
| 4 | `hasAftermarketItems` with "Aftermarket" tier item | Returns `true` |
| 5 | `hasAftermarketItems` with "Premium" tier item | Returns `false` |
| 6 | `allAftermarketConsented` with no aftermarket devices | Returns `true` |
| 7 | `allAftermarketConsented` with unconsented aftermarket device | Returns `false` |
| 8 | Existing booking flow unchanged | No regressions — all new fields are optional/defaulted |

## Acceptance Checklist

- [ ] `BookingLineItem` struct added to BookingFormData.swift
- [ ] `BookingDeviceEntry` has `lineItems`, `aftermarketConsent`, computed helpers
- [ ] `BookingDeviceEntry.empty()` initialises both new fields
- [ ] `BookingFormData.allAftermarketConsented` computed property works
- [ ] `CreateOrderDeviceRequest` has `aftermarketConsent: Int?`
- [ ] `OrderItem` has `qualityTier: String?` with decoding
- [ ] `OrderItemRequest` has `qualityTier: String?`
- [ ] `.productComponents(productTypeId:)` endpoint added to APIEndpoints
- [ ] `ProductComponents.swift` created with `ProductComponentsResponse` and `QualityTier`
- [ ] New file added to Xcode project (iOS + Mac targets)
- [ ] All 3 targets build clean (`Cmd+B`)

## Deployment

No deployment needed — model/endpoint changes only. Build verification:

```
Open Xcode → Select each scheme (iOS, Mac) → Cmd+B
```

## Handoff Notes

- Stage 02 builds the UI components that use `BookingLineItem` and the `.productComponents` endpoint
- Stage 05 (can run in parallel) uses only `CustomerDevice.aftermarketConsent` — that's a separate file not touched here
- The `CreateOrderDeviceRequest.aftermarketConsent` field won't be sent until Stage 04 wires it into `submit()`
- `OrderItemRequest.qualityTier` won't be sent until Stage 04 creates line items
