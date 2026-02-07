# Stage 01: Models & API Endpoints

## Objective

Create the data models required for the booking feature and add new `APIEndpoint` enum cases for endpoints not yet defined.

## Dependencies

`[Requires: None]` - This is the foundation stage.

## Complexity

**Low** - Simple model structs with Codable conformance + enum cases.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/Location.swift` | Location model for store/branch selection |
| `Core/Models/DeviceSearchResult.swift` | Response model for unified `/api/device-search` endpoint |
| `Core/Models/DeviceType.swift` | Device type (Phone, Tablet, Laptop, etc.) |
| `Core/Models/ServiceType.swift` | Service types available for booking (shared enum) |
| `Core/Models/CompanyPublicInfo.swift` | Company branding/defaults from `/api/company/public-info` |

## Files to Modify

| File | Changes |
|------|---------|
| `Core/Networking/APIEndpoints.swift` | Add `.locations`, `.deviceSearch(query:)`, `.deviceTypes`, `.companyPublicInfo` cases |

---

## Implementation Details

### APIEndpoints.swift (Modifications)

Add these new cases to the `APIEndpoint` enum:

```swift
// MARK: - Booking / Lookup

case locations
case deviceSearch(query: String)
case deviceTypes
case companyPublicInfo
```

Add to `path`:
```swift
case .locations:
    return "/api/locations"
case .deviceSearch:
    return "/api/device-search"
case .deviceTypes:
    return "/api/device-types"
case .companyPublicInfo:
    return "/api/company/public-info"
```

Add `.locations`, `.deviceSearch`, `.deviceTypes`, `.companyPublicInfo` to the GET cases in `method`.

Add to `queryItems`:
```swift
case .deviceSearch(let query):
    return [URLQueryItem(name: "q", value: query)]
```

**Fix existing `.clientSearch` queryItems** (bug in current code — backend expects `?email=` not `?q=`):
```swift
// BEFORE (wrong):
case .clientSearch(let query):
    return [URLQueryItem(name: "q", value: query)]

// AFTER (correct):
case .clientSearch(let query):
    return [URLQueryItem(name: "email", value: query)]
```

**Do NOT add `.companyPublicInfo` to the no-auth cases.** It requires authentication (uses JWT to scope to the correct company). It should remain in the default `requiresAuth = true` group.

### Location.swift

> **Note:** Locations are read-only (fetched from `GET /api/locations`, never sent back), so this uses `Decodable` not `Codable`.
>
> **Backend fields omitted:** The backend also returns `google_place_id`, `apple_maps_url`, `trustpilot_url`, `yelp_url`, `opening_hours` (JSON object), `created_at`, `updated_at`, and `social_media` (array). These are not needed for the booking flow but could be added later if a location detail view is built.

```swift
//
//  Location.swift
//  Repair Minder
//

import Foundation

/// Full location model for booking (extends the simpler LocationOption in DeviceQueueItem.swift)
/// Uses Decodable only — locations are read-only from GET /api/locations
struct Location: Identifiable, Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let countryCode: String?
    let phone: String?
    let email: String?
    let isPrimary: Bool?
    let latitude: Double?
    let longitude: Double?
    let phoneCountryCode: String?
    let websiteUrl: String?

    var fullAddress: String {
        [addressLine1, city, postcode]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

extension Location {
    static var sample: Location {
        Location(
            id: "loc-1",
            name: "Main Store",
            addressLine1: "123 High Street",
            addressLine2: nil,
            city: "London",
            county: "Greater London",
            postcode: "SW1A 1AA",
            countryCode: "GB",
            phone: "020 1234 5678",
            email: "store@example.com",
            isPrimary: true,
            latitude: 51.5074,
            longitude: -0.1278,
            phoneCountryCode: "GB",
            websiteUrl: nil
        )
    }
}
```

### DeviceSearchResult.swift

The backend `/api/device-search?q=<query>` endpoint returns matching brands AND models in a single response. This replaces the separate Brand/DeviceModel approach.

```swift
//
//  DeviceSearchResult.swift
//  Repair Minder
//

import Foundation

/// Response from GET /api/device-search?q=<query>
/// Returns matching brands and models in a single response
struct DeviceSearchResponse: Decodable, Sendable {
    let brands: [DeviceSearchBrand]
    let models: [DeviceSearchModel]
}

/// A brand returned from the device search endpoint
struct DeviceSearchBrand: Identifiable, Decodable, Equatable, Sendable, Hashable {
    let id: String
    let name: String
    let category: String?
}

/// A model returned from the device search endpoint
struct DeviceSearchModel: Identifiable, Decodable, Equatable, Sendable, Hashable {
    let id: String
    let brandId: String
    let brandName: String?
    let name: String
    let displayName: String?

    /// Full display name with brand
    var fullDisplayName: String {
        displayName ?? (brandName.map { "\($0) \(name)" } ?? name)
    }
}

extension DeviceSearchResponse {
    static var sample: DeviceSearchResponse {
        DeviceSearchResponse(
            brands: [
                DeviceSearchBrand(id: "brand-1", name: "Apple", category: "phone"),
                DeviceSearchBrand(id: "brand-2", name: "Samsung", category: "phone"),
            ],
            models: [
                DeviceSearchModel(id: "model-1", brandId: "brand-1", brandName: "Apple", name: "iPhone 14 Pro", displayName: "Apple iPhone 14 Pro"),
                DeviceSearchModel(id: "model-2", brandId: "brand-1", brandName: "Apple", name: "iPhone 15", displayName: "Apple iPhone 15"),
            ]
        )
    }
}
```

### DeviceType.swift

> **Important:** `DeviceTypeOption` (id, name, slug) already exists in `DeviceQueueItem.swift` (line 48). The backend `GET /api/device-types` returns those same 3 fields plus `is_system`, `device_count`, and `sort_order`.
>
> **Recommendation:** Create `DeviceType` as a separate struct from `DeviceTypeOption` (in `DeviceQueueItem.swift`). `DeviceTypeOption` has non-optional `slug: String` and is used by the queue filters. `DeviceType` has optional `slug: String?` and extra fields (`isSystem`, `deviceCount`, `sortOrder`). Both types serve different purposes and should coexist. Do NOT try to extend or unify them — the different optionality of `slug` makes extending awkward.
>
> Device types are read-only (fetched from API, never sent back), so this uses `Decodable` not `Codable`. The backend already casts `is_system` to a JS boolean (`!!t.is_system`), but the custom decoder below handles the Int-or-Bool case defensively since SQLite/D1 may change behaviour.

```swift
//
//  DeviceType.swift
//  Repair Minder
//

import Foundation

struct DeviceType: Identifiable, Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let slug: String?
    let isSystem: Bool?
    let deviceCount: Int?
    let sortOrder: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, slug, isSystem, deviceCount, sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        deviceCount = try container.decodeIfPresent(Int.self, forKey: .deviceCount)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)

        // Handle Bool-or-Int from SQLite
        if let boolVal = try? container.decodeIfPresent(Bool.self, forKey: .isSystem) {
            isSystem = boolVal
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .isSystem) {
            isSystem = intVal != 0
        } else {
            isSystem = nil
        }
    }

    // Keep manual init for sample data
    init(id: String, name: String, slug: String?, isSystem: Bool?, deviceCount: Int?, sortOrder: Int?) {
        self.id = id
        self.name = name
        self.slug = slug
        self.isSystem = isSystem
        self.deviceCount = deviceCount
        self.sortOrder = sortOrder
    }

    var systemImage: String {
        switch slug {
        case "phone", "mobile": return "iphone"
        case "tablet", "ipad": return "ipad"
        case "laptop", "macbook": return "laptopcomputer"
        case "desktop", "imac": return "desktopcomputer"
        case "watch", "smartwatch": return "applewatch"
        case "console", "gaming": return "gamecontroller.fill"
        case "repair": return "wrench.and.screwdriver"
        case "buyback": return "arrow.triangle.2.circlepath"
        default: return "cpu"
        }
    }
}

extension DeviceType {
    static var sample: DeviceType {
        DeviceType(id: "type-1", name: "Phone", slug: "phone", isSystem: true, deviceCount: 5, sortOrder: 1)
    }

    static var sampleList: [DeviceType] {
        [
            DeviceType(id: "type-1", name: "Phone", slug: "phone", isSystem: true, deviceCount: 5, sortOrder: 1),
            DeviceType(id: "type-2", name: "Tablet", slug: "tablet", isSystem: true, deviceCount: 3, sortOrder: 2),
            DeviceType(id: "type-3", name: "Laptop", slug: "laptop", isSystem: true, deviceCount: 2, sortOrder: 3),
            DeviceType(id: "type-4", name: "Desktop", slug: "desktop", isSystem: true, deviceCount: 1, sortOrder: 4)
        ]
    }
}
```

### ServiceType.swift

> **Backend support:** The backend `POST /api/orders` only has full booking flows for `repair` and `buyback`.
> While `accessory` and `device_sale` exist as item types in the backend (`ITEM_TYPES`), and
> `accessories_in_store` / `counter_sale` exist as intake methods, there is no dedicated booking wizard
> flow for these in the order creation endpoint. The `.accessories` and `.deviceSale` cases are kept
> here for future use but marked as unavailable via `isAvailable`.

```swift
//
//  ServiceType.swift
//  Repair Minder
//

import SwiftUI

/// Service types available for booking — values match backend workflow conventions.
/// Available types are filtered at runtime based on company settings (buyback_enabled, etc.)
/// and `isAvailable` (backend support).
enum ServiceType: String, CaseIterable, Identifiable {
    case repair = "repair"
    case buyback = "buyback"
    case accessories = "accessories"
    case deviceSale = "device_sale"

    var id: String { rawValue }

    /// Whether the backend POST /api/orders supports a full booking flow for this type.
    /// `.accessories` and `.deviceSale` have backend item types but no dedicated booking flow yet.
    var isAvailable: Bool {
        switch self {
        case .repair, .buyback: return true
        case .accessories, .deviceSale: return false
        }
    }

    var title: String {
        switch self {
        case .repair: return "Repair"
        case .buyback: return "Buyback"
        case .accessories: return "Accessories"
        case .deviceSale: return "Device Sale"
        }
    }

    var subtitle: String {
        switch self {
        case .repair: return "Book in a device for repair"
        case .buyback: return "Purchase a customer device"
        case .accessories: return "Sell accessories or parts"
        case .deviceSale: return "Sell a buyback device"
        }
    }

    var icon: String {
        switch self {
        case .repair: return "wrench.and.screwdriver.fill"
        case .buyback: return "arrow.triangle.2.circlepath.circle.fill"
        case .accessories: return "bag.fill"
        case .deviceSale: return "tag.fill"
        }
    }

    var color: Color {
        switch self {
        case .repair: return .blue
        case .buyback: return .green
        case .accessories: return .purple
        case .deviceSale: return .orange
        }
    }
}
```

### CompanyPublicInfo.swift

> The `.companyPublicInfo` endpoint is added in this stage but has no model — this fills that gap.
> The backend `GET /api/company/public-info` returns branding fields scoped to the authenticated user's company.
> This is used by the booking flow for: terms & conditions text, currency, default country code,
> and whether buyback is enabled.

```swift
//
//  CompanyPublicInfo.swift
//  Repair Minder
//

import Foundation

/// Response from GET /api/company/public-info
/// Public branding and booking defaults for the authenticated user's company.
/// Uses Decodable only — this is read-only data.
///
/// Fields are optional because the backend may omit them depending on company setup.
/// `buybackEnabled` needs Bool-or-Int handling (SQLite/D1 may return 0/1).
struct CompanyPublicInfo: Decodable, Sendable {
    let id: String
    let name: String?
    let logoUrl: String?
    let vatNumber: String?
    let termsConditions: String?
    let privacyPolicy: String?
    let customerPortalUrl: String?
    let currencyCode: String?
    let defaultCountryCode: String?
    let buybackEnabled: Bool?

    // No raw values — let .convertFromSnakeCase handle conversion
    private enum CodingKeys: String, CodingKey {
        case id, name, logoUrl, vatNumber, termsConditions, privacyPolicy
        case customerPortalUrl, currencyCode, defaultCountryCode
        case buybackEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        logoUrl = try container.decodeIfPresent(String.self, forKey: .logoUrl)
        vatNumber = try container.decodeIfPresent(String.self, forKey: .vatNumber)
        termsConditions = try container.decodeIfPresent(String.self, forKey: .termsConditions)
        privacyPolicy = try container.decodeIfPresent(String.self, forKey: .privacyPolicy)
        customerPortalUrl = try container.decodeIfPresent(String.self, forKey: .customerPortalUrl)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
        defaultCountryCode = try container.decodeIfPresent(String.self, forKey: .defaultCountryCode)

        // Handle Bool-or-Int from SQLite
        if let boolVal = try? container.decodeIfPresent(Bool.self, forKey: .buybackEnabled) {
            buybackEnabled = boolVal
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .buybackEnabled) {
            buybackEnabled = intVal != 0
        } else {
            buybackEnabled = nil
        }
    }

    // Manual init for sample data
    init(id: String, name: String?, logoUrl: String?, vatNumber: String?, termsConditions: String?, privacyPolicy: String?, customerPortalUrl: String?, currencyCode: String?, defaultCountryCode: String?, buybackEnabled: Bool?) {
        self.id = id
        self.name = name
        self.logoUrl = logoUrl
        self.vatNumber = vatNumber
        self.termsConditions = termsConditions
        self.privacyPolicy = privacyPolicy
        self.customerPortalUrl = customerPortalUrl
        self.currencyCode = currencyCode
        self.defaultCountryCode = defaultCountryCode
        self.buybackEnabled = buybackEnabled
    }
}

extension CompanyPublicInfo {
    static var sample: CompanyPublicInfo {
        CompanyPublicInfo(
            id: "company-1",
            name: "RepairShop Ltd",
            logoUrl: nil,
            vatNumber: "GB123456789",
            termsConditions: "By signing this form you agree...",
            privacyPolicy: "We store your data securely...",
            customerPortalUrl: "https://app.repairminder.net",
            currencyCode: "GBP",
            defaultCountryCode: "GB",
            buybackEnabled: true
        )
    }
}
```

---

## Database Changes

**None** - iOS app uses API, no local database for booking.

---

## Test Cases

### Test 1: Location Model Decoding
```swift
// Input JSON (snake_case keys from backend, decoder auto-converts)
{
    "id": "loc-123",
    "name": "Main Store",
    "address_line_1": "123 High St",
    "city": "London",
    "postcode": "SW1A 1AA",
    "country_code": "GB"
}

// Expected: Location object with fullAddress = "123 High St, London, SW1A 1AA"
```

### Test 2: Device Search Response Decoding
```swift
// Input JSON
{
    "brands": [{ "id": "b1", "name": "Apple", "category": "phone" }],
    "models": [{ "id": "m1", "brand_id": "b1", "brand_name": "Apple", "name": "iPhone 14 Pro", "display_name": "Apple iPhone 14 Pro" }]
}

// Expected: DeviceSearchResponse with 1 brand, 1 model
```

### Test 3: CompanyPublicInfo Decoding
```swift
// Input JSON (from GET /api/company/public-info)
{
    "id": "company-1",
    "name": "RepairShop Ltd",
    "logo_url": null,
    "vat_number": "GB123456789",
    "terms_conditions": "By signing this form...",
    "privacy_policy": null,
    "customer_portal_url": "https://app.repairminder.net",
    "currency_code": "GBP",
    "default_country_code": "GB",
    "buyback_enabled": true
}

// Expected: CompanyPublicInfo with buybackEnabled = true, currencyCode = "GBP"
```

### Test 4: New APIEndpoint cases compile
```swift
let _ = APIEndpoint.locations
let _ = APIEndpoint.deviceSearch(query: "iPhone")
let _ = APIEndpoint.deviceTypes
let _ = APIEndpoint.companyPublicInfo
```

### Test 5: ServiceType.isAvailable
```swift
// repair and buyback are available (backend has full booking flow)
assert(ServiceType.repair.isAvailable == true)
assert(ServiceType.buyback.isAvailable == true)
// accessories and deviceSale are NOT available (backend has no dedicated booking flow yet)
assert(ServiceType.accessories.isAvailable == false)
assert(ServiceType.deviceSale.isAvailable == false)
```

---

## Acceptance Checklist

- [ ] `Location.swift` created with `Decodable` conformance (not Codable — read-only)
- [ ] `DeviceSearchResult.swift` created with `DeviceSearchResponse`, `DeviceSearchBrand`, `DeviceSearchModel`
- [ ] `DeviceType.swift` created with `Decodable` conformance and `systemImage` computed property (consider extending `DeviceTypeOption` instead — see note)
- [ ] `CompanyPublicInfo.swift` created with all 10 fields from `GET /api/company/public-info`
- [ ] `ServiceType.swift` created with `isAvailable` returning `false` for `.accessories` and `.deviceSale`
- [ ] `APIEndpoints.swift` updated with `.locations`, `.deviceSearch(query:)`, `.deviceTypes`, `.companyPublicInfo`
- [ ] New endpoint cases have correct path, method, queryItems, and requiresAuth (`.companyPublicInfo` requires auth!)
- [ ] Fix existing `.clientSearch` queryItems: change `"q"` to `"email"` (backend expects `?email=`)
- [ ] All models have sample data for previews
- [ ] Project compiles without errors

---

## Deployment

```bash
# Build to verify compilation
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

**Verification:** Build succeeds with no errors.

---

## Handoff Notes

- Models are ready for use in view models
- All backend API endpoints already exist — new `APIEndpoint` enum cases added in this stage
- All models use snake_case to camelCase automatic conversion via `.convertFromSnakeCase` decoder — do NOT add explicit raw values in CodingKeys
- `DeviceSearchResponse` replaces the old Brand/DeviceModel approach — use unified search
- `CompanyPublicInfo` provides booking defaults (currency, country code, buyback flag, terms text)
- `ServiceType.isAvailable` gates UI — only show `.repair` and `.buyback` until backend adds dedicated flows for accessories/device sale
- `Location` and `DeviceType` use `Decodable` (not `Codable`) — they are read-only from the API
- Sample data provided for SwiftUI previews
- [See: Stage 02] will use these models in BookingFormData and BookingViewModel
