# Stage 14: White-Label Support

## Objective

Enable the app to be re-published under different client brands (logo, colors, app name, bundle ID) while maintaining a single codebase. Each branded version can be submitted to the App Store as a separate app.

---

## Dependencies

**Requires:** All previous stages complete (core app fully functional)

---

## Complexity

**Medium** - Build configuration, asset management, xcconfig files

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Shared Codebase                       │
│  (All features, networking, Core Data, business logic)   │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ Repair Minder │   │ Client A App  │   │ Client B App  │
│   (Default)   │   │   (Branded)   │   │   (Branded)   │
├───────────────┤   ├───────────────┤   ├───────────────┤
│ Bundle ID:    │   │ Bundle ID:    │   │ Bundle ID:    │
│ com.mendmyi.  │   │ com.clienta.  │   │ com.clientb.  │
│ repairminder  │   │ repairs       │   │ workshop      │
├───────────────┤   ├───────────────┤   ├───────────────┤
│ Colors: Blue  │   │ Colors: Green │   │ Colors: Red   │
│ Logo: RM      │   │ Logo: A       │   │ Logo: B       │
└───────────────┘   └───────────────┘   └───────────────┘
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Configuration/Base.xcconfig` | Shared build settings |
| `Configuration/RepairMinder.xcconfig` | Default brand config |
| `Configuration/ClientA.xcconfig` | Client A brand config |
| `Core/Branding/BrandConfiguration.swift` | Runtime brand settings |
| `Core/Branding/BrandColors.swift` | Dynamic color palette |
| `Core/Branding/BrandAssets.swift` | Logo/image management |
| `Resources/Brands/RepairMinder/` | Default brand assets |
| `Resources/Brands/ClientA/` | Client A brand assets |

---

## Implementation Details

### 1. Build Configuration Files

```xcconfig
// Configuration/Base.xcconfig
// Shared settings for all brands

SWIFT_VERSION = 5.9
IPHONEOS_DEPLOYMENT_TARGET = 17.0
TARGETED_DEVICE_FAMILY = 1,2
ENABLE_BITCODE = NO
```

```xcconfig
// Configuration/RepairMinder.xcconfig
// Default Repair Minder brand

#include "Base.xcconfig"

PRODUCT_BUNDLE_IDENTIFIER = com.mendmyi.repairminder
PRODUCT_NAME = Repair Minder
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1

// Brand identifiers
BRAND_ID = repairminder
BRAND_API_SUBDOMAIN = api
BRAND_PRIMARY_COLOR = 0x007AFF
BRAND_SECONDARY_COLOR = 0x5856D6

// Info.plist values
INFOPLIST_KEY_CFBundleDisplayName = Repair Minder
INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.business
```

```xcconfig
// Configuration/ClientA.xcconfig
// Example client brand

#include "Base.xcconfig"

PRODUCT_BUNDLE_IDENTIFIER = com.clienta.repairshop
PRODUCT_NAME = ClientA Repairs
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1

// Brand identifiers
BRAND_ID = clienta
BRAND_API_SUBDOMAIN = clienta.api
BRAND_PRIMARY_COLOR = 0x34C759
BRAND_SECONDARY_COLOR = 0x30D158

// Info.plist values
INFOPLIST_KEY_CFBundleDisplayName = ClientA Repairs
INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.business
```

### 2. Brand Configuration (Runtime)

```swift
// Core/Branding/BrandConfiguration.swift
import Foundation

struct BrandConfiguration {
    let id: String
    let displayName: String
    let apiBaseURL: URL
    let supportEmail: String
    let supportURL: URL?
    let termsURL: URL?
    let privacyURL: URL?
    let colors: BrandColors

    static let current: BrandConfiguration = {
        // Load from Info.plist values set by xcconfig
        let brandId = Bundle.main.infoDictionary?["BRAND_ID"] as? String ?? "repairminder"
        return loadBrand(id: brandId)
    }()

    private static func loadBrand(id: String) -> BrandConfiguration {
        switch id {
        case "repairminder":
            return BrandConfiguration(
                id: "repairminder",
                displayName: "Repair Minder",
                apiBaseURL: URL(string: "https://api.repairminder.com")!,
                supportEmail: "support@repairminder.com",
                supportURL: URL(string: "https://repairminder.com/help"),
                termsURL: URL(string: "https://repairminder.com/terms"),
                privacyURL: URL(string: "https://repairminder.com/privacy"),
                colors: .repairMinder
            )
        case "clienta":
            return BrandConfiguration(
                id: "clienta",
                displayName: "ClientA Repairs",
                apiBaseURL: URL(string: "https://clienta.api.repairminder.com")!,
                supportEmail: "support@clienta.com",
                supportURL: URL(string: "https://clienta.com/help"),
                termsURL: URL(string: "https://clienta.com/terms"),
                privacyURL: URL(string: "https://clienta.com/privacy"),
                colors: .clientA
            )
        default:
            fatalError("Unknown brand ID: \(id)")
        }
    }
}
```

### 3. Brand Colors

```swift
// Core/Branding/BrandColors.swift
import SwiftUI

struct BrandColors {
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surface: Color
    let error: Color
    let success: Color
    let warning: Color

    // Default Repair Minder colors
    static let repairMinder = BrandColors(
        primary: Color(hex: 0x007AFF),      // iOS Blue
        secondary: Color(hex: 0x5856D6),    // Purple
        accent: Color(hex: 0xFF9500),       // Orange
        background: Color(.systemBackground),
        surface: Color(.secondarySystemBackground),
        error: Color(hex: 0xFF3B30),
        success: Color(hex: 0x34C759),
        warning: Color(hex: 0xFF9500)
    )

    // Client A colors (example)
    static let clientA = BrandColors(
        primary: Color(hex: 0x34C759),      // Green
        secondary: Color(hex: 0x30D158),    // Light Green
        accent: Color(hex: 0x007AFF),       // Blue
        background: Color(.systemBackground),
        surface: Color(.secondarySystemBackground),
        error: Color(hex: 0xFF3B30),
        success: Color(hex: 0x34C759),
        warning: Color(hex: 0xFF9500)
    )
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// Environment key for brand colors
struct BrandColorsKey: EnvironmentKey {
    static let defaultValue = BrandConfiguration.current.colors
}

extension EnvironmentValues {
    var brandColors: BrandColors {
        get { self[BrandColorsKey.self] }
        set { self[BrandColorsKey.self] = newValue }
    }
}
```

### 4. Brand Assets

```swift
// Core/Branding/BrandAssets.swift
import SwiftUI

struct BrandAssets {
    let logoImage: Image
    let logoImageSmall: Image
    let appIcon: Image
    let splashBackground: Color

    static let current: BrandAssets = {
        let brandId = BrandConfiguration.current.id
        return BrandAssets(
            logoImage: Image("\(brandId)_logo", bundle: .main),
            logoImageSmall: Image("\(brandId)_logo_small", bundle: .main),
            appIcon: Image("\(brandId)_appicon", bundle: .main),
            splashBackground: BrandConfiguration.current.colors.primary
        )
    }()
}

// Convenience view for brand logo
struct BrandLogo: View {
    enum Size {
        case small, medium, large

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 60
            case .large: return 100
            }
        }
    }

    let size: Size

    var body: some View {
        BrandAssets.current.logoImage
            .resizable()
            .scaledToFit()
            .frame(width: size.dimension, height: size.dimension)
    }
}
```

### 5. Using Brand Configuration Throughout App

```swift
// Update LoginView to use branding
struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.brandColors) var colors

    var body: some View {
        VStack(spacing: 32) {
            // Brand logo instead of hardcoded icon
            BrandLogo(size: .large)

            Text("Welcome to \(BrandConfiguration.current.displayName)")
                .font(.title)
                .fontWeight(.bold)

            // Login form...

            Button("Sign In") {
                // ...
            }
            .buttonStyle(.borderedProminent)
            .tint(colors.primary) // Use brand color
        }
    }
}
```

```swift
// Update AboutView to use branding
struct AboutView: View {
    let brand = BrandConfiguration.current

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    BrandLogo(size: .large)

                    Text(brand.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

            Section("Legal") {
                if let termsURL = brand.termsURL {
                    Link("Terms of Service", destination: termsURL)
                }
                if let privacyURL = brand.privacyURL {
                    Link("Privacy Policy", destination: privacyURL)
                }
            }

            Section("Support") {
                if let supportURL = brand.supportURL {
                    Link("Help Center", destination: supportURL)
                }
                Link("Contact Support", destination: URL(string: "mailto:\(brand.supportEmail)")!)
            }
        }
        .navigationTitle("About")
    }
}
```

### 6. Asset Catalog Structure

```
Resources/
├── Assets.xcassets/
│   ├── AppIcon.appiconset/          # Default (Repair Minder)
│   ├── AccentColor.colorset/
│   ├── repairminder_logo.imageset/
│   ├── repairminder_logo_small.imageset/
│   └── Colors/
│       ├── PrimaryColor.colorset/
│       └── SecondaryColor.colorset/
│
├── ClientA.xcassets/                 # Client A assets
│   ├── AppIcon.appiconset/          # Different icon
│   ├── AccentColor.colorset/
│   ├── clienta_logo.imageset/
│   └── clienta_logo_small.imageset/
│
└── ClientB.xcassets/                 # Client B assets
    └── ...
```

### 7. Xcode Scheme Setup

For each client brand, create a new scheme:

1. **Repair Minder** (default)
   - Build Configuration: RepairMinder
   - Uses Assets.xcassets

2. **ClientA Repairs**
   - Build Configuration: ClientA
   - Uses ClientA.xcassets

### 8. Build Script for Asset Selection

```bash
#!/bin/bash
# Scripts/select_brand_assets.sh
# Run in Build Phases to copy correct asset catalog

BRAND_ID=${BRAND_ID:-repairminder}

if [ -d "${PROJECT_DIR}/Resources/${BRAND_ID}.xcassets" ]; then
    cp -R "${PROJECT_DIR}/Resources/${BRAND_ID}.xcassets/"* "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/"
fi
```

---

## Adding a New Client Brand

### Step-by-Step Process

1. **Create Configuration File**
   ```
   Configuration/ClientNew.xcconfig
   ```
   Set bundle ID, app name, colors

2. **Create Asset Catalog**
   ```
   Resources/ClientNew.xcassets/
   ├── AppIcon.appiconset/
   ├── clientnew_logo.imageset/
   └── clientnew_logo_small.imageset/
   ```

3. **Add Brand Configuration**
   Update `BrandConfiguration.swift` with new case

4. **Create Build Configuration**
   In Xcode: Project → Info → Configurations → Duplicate "Release" → Rename to "ClientNew"

5. **Create Scheme**
   New Scheme → Select target → Set build configuration

6. **Archive & Submit**
   Select scheme → Archive → Submit to App Store Connect

---

## Multi-Tenant API Considerations

### Option A: Subdomain-Based (Recommended)
Each client gets their own subdomain:
- `https://api.repairminder.com` (default)
- `https://clienta.api.repairminder.com`
- `https://clientb.api.repairminder.com`

### Option B: Header-Based
Same API, client identified by header:
```swift
// In APIClient
var headers: [String: String] {
    var h = ["Content-Type": "application/json"]
    h["X-Brand-ID"] = BrandConfiguration.current.id
    return h
}
```

### Option C: Path-Based
Client ID in URL path:
```
https://api.repairminder.com/v1/clienta/orders
https://api.repairminder.com/v1/clientb/orders
```

---

## Push Notification Considerations

Each branded app needs:
1. **Separate APNS Certificate** (or use universal push key)
2. **Separate Bundle ID** registered in Apple Developer Portal
3. **Server-side routing** to correct APNS endpoint per brand

### Recommended: Single APNS Key
Use a single Apple Push Notification Authentication Key (.p8) which works across all apps in your developer account.

---

## App Store Submission per Brand

Each branded app requires:
- [ ] Unique Bundle ID
- [ ] Separate App Store Connect app record
- [ ] Client-specific screenshots (with their branding)
- [ ] Client-approved description text
- [ ] Client's privacy policy URL
- [ ] Client's support URL

### Automation with Fastlane

```ruby
# fastlane/Fastfile
lane :release_brand do |options|
  brand = options[:brand] || "repairminder"

  build_app(
    scheme: brand.capitalize,
    configuration: "Release-#{brand.capitalize}",
    export_options: {
      provisioningProfiles: {
        "com.#{brand}.repairs" => "#{brand} App Store Profile"
      }
    }
  )

  upload_to_app_store(
    app_identifier: "com.#{brand}.repairs",
    skip_screenshots: true,
    skip_metadata: false
  )
end

# Usage: fastlane release_brand brand:clienta
```

---

## Test Cases

| Test | Expected |
|------|----------|
| Build with default config | Shows Repair Minder branding |
| Build with ClientA config | Shows ClientA branding |
| Logo displays correctly | Correct brand logo on login, about |
| Colors apply correctly | Primary color on buttons, accents |
| API calls use correct base URL | Requests go to brand's subdomain |
| About page shows correct info | Brand name, support email, legal links |
| Push notifications work | Each brand receives its own notifications |

---

## Acceptance Checklist

- [ ] xcconfig files created for default and at least one client
- [ ] BrandConfiguration loads correct settings per build
- [ ] BrandColors applies throughout app
- [ ] BrandAssets loads correct logos/icons
- [ ] Asset catalogs set up per brand
- [ ] Build schemes created per brand
- [ ] API base URL configurable per brand
- [ ] About page uses brand configuration
- [ ] Support/legal links use brand URLs
- [ ] App can be archived per brand
- [ ] Each brand has unique bundle ID

---

## Adding Your First Client Brand

When you have a client who wants their own branded version:

1. Get from client:
   - Brand name
   - Primary/secondary colors (hex values)
   - Logo files (SVG or high-res PNG)
   - App icon (1024x1024)
   - Bundle ID preference
   - Support email
   - Privacy policy URL
   - Terms of service URL

2. Create the brand assets and configuration (follow steps above)

3. Test thoroughly in simulator

4. Create App Store Connect listing

5. Submit for review

---

## Cost Considerations

Each white-label client app:
- **Apple Developer fee**: Covered by your account (one fee covers all apps)
- **App Store submission**: No additional cost
- **Push notifications**: No additional cost (with shared .p8 key)
- **API hosting**: May need tenant isolation/scaling

---

## Future Enhancements

- [ ] Dynamic brand loading from server (no rebuild required)
- [ ] Brand-specific feature flags
- [ ] Custom onboarding flows per brand
- [ ] Brand-specific notification preferences
- [ ] Analytics per brand
