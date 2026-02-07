# Device Detail Fixes

## Overview
Fix two bugs affecting the Device Detail view on **both iPhone and iPad**:
1. A decoding failure caused by a type mismatch between the backend response and the iOS model for `damage_matches_reported` (and potentially `additional_issues_found`)
2. iPad split view showing stale data when switching between devices due to `@State` reuse

## Issue 1: Decoding Failures (iPhone + iPad)

### Problem
The device detail view shows "Failed to decode response: The data couldn't be read because it isn't in the correct format" when loading any device where certain fields have non-null values.

**Root cause**: The iOS `DeviceDetail` model declares `damageMatchesReported` as `Bool?`, but the backend passes it raw from the DB. The `damage_matches_reported` column is **TEXT** in the database (migration 0114). When set, the JSON sends a string (not a boolean), which Swift's `JSONDecoder` cannot decode as `Bool`.

Additionally, `additional_issues_found` is `INTEGER DEFAULT 0` in the DB — the backend passes it raw, so it's always a number (usually `0`). The iOS model has `additionalIssuesFound: Int?` which handles this correctly. However, this field is used in the view as `if additionalIssuesFound != 0` alongside `damageMatchesReported: Bool?` which is the actual failure.

### Affected Files

**Backend** — `worker/device_handlers.js`, `handleGetOrderDevice` function (~line 902-906):
```js
// These are passed raw from DB — no type conversion applied
visual_check: device.visual_check,              // TEXT col → String in JSON ✓ (iOS: String?)
electrical_check: device.electrical_check,      // TEXT col → String in JSON ✓ (iOS: String?)
mechanical_check: device.mechanical_check,      // TEXT col → String in JSON ✓ (iOS: String?)
damage_matches_reported: device.damage_matches_reported,  // TEXT col → String in JSON ✗ (iOS: Bool?)
diagnosis_conclusion: device.diagnosis_conclusion,        // TEXT col → String in JSON ✓ (iOS: String?)
```

**iOS** — `Repair Minder/Core/Models/DeviceDetail.swift` (line 58):
```swift
let damageMatchesReported: Bool?  // ← Expects Bool, but API sends String or null
```

### Fix (two options — pick one)

**Option A (Backend fix)**: Convert the field to a proper boolean in the response, consistent with other boolean fields:
```js
// Before
damage_matches_reported: device.damage_matches_reported,

// After
damage_matches_reported: device.damage_matches_reported != null
  ? !!device.damage_matches_reported
  : null,
```

**Option B (iOS fix)**: Change the iOS model to match what the API actually sends:
```swift
// Before
let damageMatchesReported: Bool?

// After
let damageMatchesReported: String?
```
Then update the view's usage at DeviceDetailView.swift line 497-501 to compare the string.

**Recommended: Option A** — fix the backend to send proper types. This is consistent with how `data_backup_offered`, `is_under_warranty`, etc. are handled in the same response.

### Verification
- Build and run on iPhone
- Navigate to any device detail → should load without decode errors
- Navigate to a device where `damage_matches_reported` has been set → should still load
- Check Xcode console for any `❌ DECODE ERROR` log lines (there's debug logging at APIClient.swift:281-294)

---

## Issue 2: iPad Split View Stale Data

### Problem
`DeviceDetailView` uses `@State` for its view model, which is only initialized once per structural identity. In `NavigationSplitView` detail panes (iPad), selecting a different device doesn't change the view's structural identity — so `@State` retains the old view model and `.task` doesn't re-fire. The user sees stale data from the previously selected device.

iPhone is not affected because `navigationDestination` pushes new views on the stack (fresh `@State` each time).

### Affected Files (iOS)
- `Repair Minder/Features/Staff/Devices/DevicesView.swift` — iPad detail pane (line 65)
- `Repair Minder/Features/Staff/Dashboard/MyQueueView.swift` — iPad detail pane (line 57)

### Fix
Add `.id()` modifier to `DeviceDetailView` in both iPad layouts to force SwiftUI to recreate the view (and its `@State`) when the selection changes:

```swift
// DevicesView.swift iPadBody
DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)
    .id("\(nav.orderId)-\(nav.deviceId)")

// MyQueueView.swift iPadBody
DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)
    .id("\(nav.orderId)-\(nav.deviceId)")
```

### Verification
- Build and run on iPad simulator
- Select device A → confirm it loads
- Select device B → confirm it loads fresh data (not device A's data)
- Repeat from My Queue tab

---

## Execution Order
1. **Backend first** — Deploy the `damage_matches_reported` fix so the API returns correct types
2. **iOS second** — Add `.id()` modifiers to iPad layouts
3. **Verify** — Build iOS app, test device detail on both iPhone and iPad

## Files Changed Summary

| File | Project | Change |
|------|---------|--------|
| `worker/device_handlers.js` | Backend | Add `!!` conversion for `damage_matches_reported` |
| `DevicesView.swift` | iOS | Add `.id()` to iPad detail pane |
| `MyQueueView.swift` | iOS | Add `.id()` to iPad detail pane |
