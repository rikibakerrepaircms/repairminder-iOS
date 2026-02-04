# RepairMinder iOS - Stage 14: White-Label Support

You are implementing Stage 14 of the RepairMinder iOS app.

**NOTE:** This is the FINAL stage. Requires all previous stages (including 13) to be complete.

---

## CONFIGURATION

**Master Plan:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/00-master-plan.md`
**Stage Plan:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/14-white-label.md`
**Test Tokens & API Reference:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md`
**Xcode Project:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/`

---

## TASK OVERVIEW

Enable the app to be re-published under different client brands (logo, colors, app name, bundle ID) while maintaining a single codebase. Each branded version can be submitted to the App Store as a separate app.

---

## FILES TO CREATE

| File | Purpose |
|------|---------|
| `Configuration/Base.xcconfig` | Shared build settings |
| `Configuration/RepairMinder.xcconfig` | Default brand config |
| `Configuration/ClientA.xcconfig` | Example client brand config |
| `Core/Branding/BrandConfiguration.swift` | Runtime brand settings loader |
| `Core/Branding/BrandColors.swift` | Dynamic color palette |
| `Core/Branding/BrandAssets.swift` | Logo/image management |
| `Shared/Components/BrandLogo.swift` | Brand logo view component |
| `Resources/Brands/RepairMinder/` | Default brand asset catalog |

---

## FILES TO MODIFY

| File | Changes |
|------|---------|
| `Info.plist` | Add `BRAND_ID` key from xcconfig |
| `Features/Auth/LoginView.swift` | Use BrandLogo, BrandConfiguration.displayName |
| `Features/Settings/AboutView.swift` | Use brand name, support URL, legal URLs |
| `Core/Networking/APIClient.swift` | Use BrandConfiguration.apiBaseURL |
| `Core/Config/Environment.swift` | Use brand-specific base URL |

---

## XCCONFIG STRUCTURE

### Base.xcconfig (shared)
```xcconfig
SWIFT_VERSION = 5.9
IPHONEOS_DEPLOYMENT_TARGET = 17.0
TARGETED_DEVICE_FAMILY = 1,2
ENABLE_BITCODE = NO
```

### RepairMinder.xcconfig (default brand)
```xcconfig
#include "Base.xcconfig"

PRODUCT_BUNDLE_IDENTIFIER = com.mendmyi.repairminder
PRODUCT_NAME = Repair Minder
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1

// Brand identifiers
BRAND_ID = repairminder
BRAND_API_SUBDOMAIN = api

// Info.plist values
INFOPLIST_KEY_CFBundleDisplayName = Repair Minder
```

### ClientA.xcconfig (example client)
```xcconfig
#include "Base.xcconfig"

PRODUCT_BUNDLE_IDENTIFIER = com.clienta.repairshop
PRODUCT_NAME = ClientA Repairs
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1

// Brand identifiers
BRAND_ID = clienta
BRAND_API_SUBDOMAIN = clienta.api

// Info.plist values
INFOPLIST_KEY_CFBundleDisplayName = ClientA Repairs
```

---

## BRAND CONFIGURATION

```swift
// Core/Branding/BrandConfiguration.swift
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

---

## BRAND COLORS

```swift
// Core/Branding/BrandColors.swift
struct BrandColors {
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surface: Color
    let error: Color
    let success: Color
    let warning: Color

    static let repairMinder = BrandColors(
        primary: Color(hex: 0x007AFF),
        secondary: Color(hex: 0x5856D6),
        accent: Color(hex: 0xFF9500),
        background: Color(.systemBackground),
        surface: Color(.secondarySystemBackground),
        error: Color(hex: 0xFF3B30),
        success: Color(hex: 0x34C759),
        warning: Color(hex: 0xFF9500)
    )

    static let clientA = BrandColors(
        primary: Color(hex: 0x34C759),      // Green
        secondary: Color(hex: 0x30D158),
        accent: Color(hex: 0x007AFF),
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

---

## BRAND ASSETS

```swift
// Core/Branding/BrandAssets.swift
struct BrandAssets {
    let logoImage: Image
    let logoImageSmall: Image
    let splashBackground: Color

    static let current: BrandAssets = {
        let brandId = BrandConfiguration.current.id
        return BrandAssets(
            logoImage: Image("\(brandId)_logo", bundle: .main),
            logoImageSmall: Image("\(brandId)_logo_small", bundle: .main),
            splashBackground: BrandConfiguration.current.colors.primary
        )
    }()
}

// Shared/Components/BrandLogo.swift
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

---

## ASSET CATALOG STRUCTURE

```
Resources/
├── Assets.xcassets/              # Default (Repair Minder)
│   ├── AppIcon.appiconset/
│   ├── AccentColor.colorset/
│   ├── repairminder_logo.imageset/
│   └── repairminder_logo_small.imageset/
│
└── ClientA.xcassets/             # Client A assets (example)
    ├── AppIcon.appiconset/
    ├── clienta_logo.imageset/
    └── clienta_logo_small.imageset/
```

---

## XCODE CONFIGURATION

1. **Create Build Configurations:**
   - Project → Info → Configurations
   - Duplicate "Debug" → "Debug-RepairMinder", "Debug-ClientA"
   - Duplicate "Release" → "Release-RepairMinder", "Release-ClientA"

2. **Assign xcconfig files:**
   - Debug-RepairMinder → RepairMinder.xcconfig
   - Release-RepairMinder → RepairMinder.xcconfig
   - Debug-ClientA → ClientA.xcconfig
   - Release-ClientA → ClientA.xcconfig

3. **Create Schemes:**
   - "Repair Minder" scheme → uses RepairMinder configurations
   - "ClientA Repairs" scheme → uses ClientA configurations

4. **Add BRAND_ID to Info.plist:**
   ```xml
   <key>BRAND_ID</key>
   <string>$(BRAND_ID)</string>
   ```

---

## USAGE IN VIEWS

```swift
// LoginView.swift
struct LoginView: View {
    @Environment(\.brandColors) var colors

    var body: some View {
        VStack {
            BrandLogo(size: .large)

            Text("Welcome to \(BrandConfiguration.current.displayName)")
                .font(.title)

            Button("Sign In") { ... }
                .buttonStyle(.borderedProminent)
                .tint(colors.primary)
        }
    }
}

// AboutView.swift
struct AboutView: View {
    let brand = BrandConfiguration.current

    var body: some View {
        List {
            Section {
                BrandLogo(size: .large)
                Text(brand.displayName)
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
                Link("Contact Support", destination: URL(string: "mailto:\(brand.supportEmail)")!)
            }
        }
    }
}
```

---

## SCOPE BOUNDARIES

### DO:
- Create xcconfig files for default and one example client
- Create BrandConfiguration, BrandColors, BrandAssets
- Create BrandLogo component
- Update LoginView to use branding
- Update AboutView to use branding
- Update API base URL to use brand config
- Set up Xcode build configurations
- Create example scheme for client brand
- Document process for adding new brands

### DON'T:
- Don't create actual client assets (just placeholders)
- Don't set up Fastlane (document only)
- Don't create App Store Connect listings
- Don't modify core functionality

---

## ADDING A NEW CLIENT (Documentation)

When a new client wants a branded version:

1. **Get from client:**
   - Brand name
   - Primary/secondary colors (hex)
   - Logo files (SVG or high-res PNG)
   - App icon (1024x1024)
   - Bundle ID preference
   - Support email
   - Legal URLs (privacy, terms)

2. **Create files:**
   - `Configuration/ClientName.xcconfig`
   - `Resources/ClientName.xcassets/` with logos

3. **Update code:**
   - Add case to `BrandConfiguration.loadBrand()`
   - Add colors to `BrandColors`

4. **Xcode setup:**
   - Create build configurations
   - Create scheme

5. **Test and submit:**
   - Archive with client scheme
   - Submit to App Store Connect

---

## BUILD & VERIFY

```
# Build default brand
mcp__XcodeBuildMCP__session-set-defaults with scheme "Repair Minder"
mcp__XcodeBuildMCP__build_sim

# Build example client brand
mcp__XcodeBuildMCP__session-set-defaults with scheme "ClientA Repairs"
mcp__XcodeBuildMCP__build_sim
```

---

## COMPLETION CHECKLIST

- [ ] xcconfig files created (Base, RepairMinder, ClientA)
- [ ] BrandConfiguration loads correct settings
- [ ] BrandColors applies throughout app
- [ ] BrandAssets loads correct logos
- [ ] BrandLogo component works
- [ ] LoginView uses brand logo and name
- [ ] AboutView uses brand info and links
- [ ] API uses brand-specific base URL
- [ ] Build configurations created in Xcode
- [ ] Schemes created for each brand
- [ ] Default brand builds and runs correctly
- [ ] Example client brand builds correctly
- [ ] Documentation for adding new clients complete
- [ ] Both Staff and Customer targets support branding

---

## WORKER NOTES

After completing this stage, notify that:
- Stage 14 is complete
- White-label infrastructure is ready
- **THE APP IS COMPLETE AND READY FOR RELEASE**
- All 15 stages have been implemented
