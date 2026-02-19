# White-Label Configuration Guide

This document explains how to add new client brands to the RepairMinder iOS app.

## Overview

The white-label system allows the same codebase to be published under different brand names, colors, and configurations. Each brand is configured at compile time using Swift conditional compilation.

## Files Involved

| File | Purpose |
|------|---------|
| `Configuration/*.xcconfig` | Build settings for each brand |
| `Core/Branding/BrandConfiguration.swift` | Runtime brand settings |
| `Core/Branding/BrandColors.swift` | Brand color palettes |
| `Core/Branding/BrandAssets.swift` | Logo and asset management |
| `Assets.xcassets/*_logo.imageset/` | Brand logo images |

## Adding a New Client Brand

### Step 1: Gather Client Information

Collect the following from the client:

- **Brand name** (e.g., "ClientB Repairs")
- **Primary/secondary colors** (hex values)
- **Logo files** (SVG or high-res PNG, 100x100 minimum)
- **App icon** (1024x1024 PNG)
- **Bundle ID preference** (e.g., "com.clientb.repairs")
- **Support email**
- **Legal URLs** (privacy policy, terms of service)
- **Company name and location**

### Step 2: Create xcconfig File

Create `Configuration/ClientB.xcconfig`:

```xcconfig
#include "Base.xcconfig"

// App Identity
PRODUCT_BUNDLE_IDENTIFIER = com.clientb.repairs
PRODUCT_NAME = ClientB Repairs
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1

// Brand Identifiers
BRAND_ID = clientb
BRAND_API_SUBDOMAIN = clientb.api

// Info.plist Display Values
INFOPLIST_KEY_CFBundleDisplayName = ClientB Repairs
```

### Step 3: Add Brand Colors

Edit `Core/Branding/BrandColors.swift`:

```swift
static let clientB = BrandColors(
    primary: Color(hex: 0xYOUR_HEX),        // Client's primary color
    secondary: Color(hex: 0xYOUR_HEX),      // Client's secondary color
    accent: Color(hex: 0xYOUR_HEX),         // Accent color
    background: Color(.systemBackground),
    surface: Color(.secondarySystemBackground),
    error: Color(hex: 0xFF3B30),
    success: Color(hex: 0x34C759),
    warning: Color(hex: 0xFF9500)
)
```

### Step 4: Add Brand Configuration

Edit `Core/Branding/BrandConfiguration.swift`:

1. Add a case in the `loadBrand` switch statement:

```swift
case "clientb":
    return BrandConfiguration(
        id: "clientb",
        displayName: "ClientB Repairs",
        apiBaseURL: URL(string: "https://clientb.api.repairminder.com")!,
        supportEmail: "support@clientb.com",
        supportURL: URL(string: "https://clientb.com/help"),
        termsURL: URL(string: "https://clientb.com/terms"),
        privacyURL: URL(string: "https://clientb.com/privacy"),
        colors: .clientB,
        companyName: "ClientB Inc.",
        companyLocation: "Los Angeles, USA"
    )
```

2. Add the compile-time conditional in `current`:

```swift
static let current: BrandConfiguration = {
    #if BRAND_CLIENTB
    return loadBrand(id: "clientb")
    #elseif BRAND_CLIENTA
    return loadBrand(id: "clienta")
    #else
    return loadBrand(id: "repairminder")
    #endif
}()
```

### Step 5: Add Logo Assets

1. Create logo imagesets in `Assets.xcassets/`:
   - `clientb_logo.imageset/`
   - `clientb_logo_small.imageset/`

2. Add 1x, 2x, and 3x versions of the logo

3. Update `Contents.json` for each imageset

### Step 6: Create Xcode Build Configuration

In Xcode:

1. **Project → Info → Configurations**
   - Duplicate "Debug" → "Debug-ClientB"
   - Duplicate "Release" → "Release-ClientB"

2. **Assign xcconfig file:**
   - Select Debug-ClientB → Set Configuration File to `ClientB.xcconfig`
   - Select Release-ClientB → Set Configuration File to `ClientB.xcconfig`

3. **Add Swift compilation condition:**
   - Target → Build Settings → Swift Compiler - Custom Flags
   - For Debug-ClientB: Add `BRAND_CLIENTB` to Active Compilation Conditions
   - For Release-ClientB: Add `BRAND_CLIENTB` to Active Compilation Conditions

### Step 7: Create Scheme

1. **Product → Scheme → New Scheme**
2. Name it "ClientB Repairs"
3. Edit scheme:
   - Run → Build Configuration: Debug-ClientB
   - Archive → Build Configuration: Release-ClientB

### Step 8: Build and Test

```bash
# Select the client scheme in Xcode
# Or use command line:
xcodebuild -project "Repair Minder.xcodeproj" \
  -scheme "ClientB Repairs" \
  -configuration Debug-ClientB \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

### Step 9: Prepare for App Store

1. **Create App Store Connect listing:**
   - Use client's bundle ID
   - Use client's brand name and assets

2. **Archive:**
   - Select client scheme
   - Product → Archive

3. **Upload to App Store Connect:**
   - Distribute App → App Store Connect

## File Structure Summary

```
Repair Minder/
├── Configuration/
│   ├── Base.xcconfig
│   ├── RepairMinder.xcconfig
│   ├── ClientA.xcconfig
│   └── ClientB.xcconfig        # New client
├── Core/
│   └── Branding/
│       ├── BrandConfiguration.swift
│       ├── BrandColors.swift
│       └── BrandAssets.swift
└── Assets.xcassets/
    ├── repairminder_logo.imageset/
    ├── clienta_logo.imageset/
    └── clientb_logo.imageset/  # New client
```

## Testing Checklist

- [ ] App displays correct brand name
- [ ] Logo appears correctly on login screen
- [ ] Logo appears correctly on About screen
- [ ] Brand colors are applied to buttons
- [ ] About screen shows correct company info
- [ ] Support email is correct
- [ ] Legal links work correctly
- [ ] API connects to correct subdomain
- [ ] App icon is correct
- [ ] Bundle ID is correct for App Store

## Troubleshooting

### Build fails with missing brand
Ensure `BRAND_CLIENTB` is added to Swift Active Compilation Conditions for the client's build configurations.

### Logo not appearing
1. Check imageset is named correctly: `clientb_logo`
2. Verify Contents.json has correct image references
3. Ensure images are added to the project

### Wrong colors appearing
Verify the correct brand color preset is referenced in BrandConfiguration.

### API errors
Check that the client's API subdomain is correctly configured and the backend is set up for the new client.
