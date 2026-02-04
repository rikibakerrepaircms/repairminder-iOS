# Stage 01: Models

## Objective

Create the data models required for the booking feature. No API endpoint changes needed - use `APIEndpoint(path:)` directly.

## Dependencies

`[Requires: None]` - This is the foundation stage.

## Complexity

**Low** - Simple model structs with Codable conformance.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/Location.swift` | Location model for store/branch selection |
| `Core/Models/Brand.swift` | Brand model (Apple, Samsung, etc.) |
| `Core/Models/DeviceModel.swift` | Device model (iPhone 14, Galaxy S23, etc.) |
| `Core/Models/DeviceType.swift` | Device type (Phone, Tablet, Laptop, etc.) |

---

## Implementation Details

### Location.swift

```swift
//
//  Location.swift
//  Repair Minder
//

import Foundation

struct Location: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let country: String?
    let countryCode: String?
    let phone: String?
    let email: String?
    let isDefault: Bool?

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
            country: "United Kingdom",
            countryCode: "GB",
            phone: "020 1234 5678",
            email: "store@example.com",
            isDefault: true
        )
    }
}
```

### Brand.swift

```swift
//
//  Brand.swift
//  Repair Minder
//

import Foundation

struct Brand: Identifiable, Codable, Equatable, Sendable, Hashable {
    let id: String
    let name: String
    let slug: String?
    let logoUrl: String?
    let isActive: Bool?

    // For "Other" option allowing custom brand entry
    var isCustom: Bool {
        slug == "other" || slug == "custom"
    }
}

extension Brand {
    static var sample: Brand {
        Brand(id: "brand-1", name: "Apple", slug: "apple", logoUrl: nil, isActive: true)
    }

    static var sampleList: [Brand] {
        [
            Brand(id: "brand-1", name: "Apple", slug: "apple", logoUrl: nil, isActive: true),
            Brand(id: "brand-2", name: "Samsung", slug: "samsung", logoUrl: nil, isActive: true),
            Brand(id: "brand-3", name: "Google", slug: "google", logoUrl: nil, isActive: true),
            Brand(id: "brand-other", name: "Other", slug: "other", logoUrl: nil, isActive: true)
        ]
    }
}
```

### DeviceModel.swift

```swift
//
//  DeviceModel.swift
//  Repair Minder
//

import Foundation

struct DeviceModel: Identifiable, Codable, Equatable, Sendable, Hashable {
    let id: String
    let brandId: String
    let name: String
    let slug: String?
    let deviceTypeId: String?
    let isActive: Bool?

    // For display with brand
    func displayName(brandName: String?) -> String {
        if let brand = brandName {
            return "\(brand) \(name)"
        }
        return name
    }
}

extension DeviceModel {
    static var sample: DeviceModel {
        DeviceModel(
            id: "model-1",
            brandId: "brand-1",
            name: "iPhone 14 Pro",
            slug: "iphone-14-pro",
            deviceTypeId: "type-phone",
            isActive: true
        )
    }
}
```

### DeviceType.swift

```swift
//
//  DeviceType.swift
//  Repair Minder
//

import Foundation

struct DeviceType: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let slug: String?
    let icon: String?

    var systemImage: String {
        switch slug {
        case "phone", "mobile": return "iphone"
        case "tablet", "ipad": return "ipad"
        case "laptop", "macbook": return "laptopcomputer"
        case "desktop", "imac": return "desktopcomputer"
        case "watch", "smartwatch": return "applewatch"
        case "console", "gaming": return "gamecontroller.fill"
        default: return "cpu"
        }
    }
}

extension DeviceType {
    static var sample: DeviceType {
        DeviceType(id: "type-1", name: "Phone", slug: "phone", icon: nil)
    }

    static var sampleList: [DeviceType] {
        [
            DeviceType(id: "type-1", name: "Phone", slug: "phone", icon: nil),
            DeviceType(id: "type-2", name: "Tablet", slug: "tablet", icon: nil),
            DeviceType(id: "type-3", name: "Laptop", slug: "laptop", icon: nil),
            DeviceType(id: "type-4", name: "Desktop", slug: "desktop", icon: nil)
        ]
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
// Input JSON
{
    "id": "loc-123",
    "name": "Main Store",
    "addressLine1": "123 High St",
    "city": "London",
    "postcode": "SW1A 1AA",
    "countryCode": "GB"
}

// Expected: Location object with fullAddress = "123 High St, London, SW1A 1AA"
```

### Test 2: Brand Model Decoding
```swift
// Input JSON
{
    "id": "brand-1",
    "name": "Apple",
    "slug": "apple",
    "isActive": true
}

// Expected: Brand object with isCustom = false
```

---

## Acceptance Checklist

- [ ] `Location.swift` created with all properties and Codable conformance
- [ ] `Brand.swift` created with `isCustom` computed property
- [ ] `DeviceModel.swift` created with `displayName` helper
- [ ] `DeviceType.swift` created with `systemImage` computed property
- [ ] All models have sample data for previews
- [ ] Project compiles without errors

**Note:** No `APIEndpoints.swift` changes needed - use `APIEndpoint(path:)` directly in view models.

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
- All backend API endpoints already exist - use `APIEndpoint(path:)` directly, no new definitions needed
- All models use snake_case to camelCase automatic conversion via Codable
- Sample data provided for SwiftUI previews
- [See: Stage 02] will use these models in BookingFormData
