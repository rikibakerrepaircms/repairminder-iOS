# Device Detail Fixes — Execute

Read the plan at `plans/device-detail-fixes/00-master-plan.md` then implement both fixes below.

## Fix 1: Backend — `damage_matches_reported` boolean conversion

File: `/Volumes/Riki Repos/repairminder/worker/device_handlers.js`
Function: `handleGetOrderDevice` (~line 905)

The `damage_matches_reported` column is TEXT in the database but the iOS model expects `Bool?`. The backend passes it raw, so when it has a value the iOS app fails to decode the entire response.

Change:
```js
damage_matches_reported: device.damage_matches_reported,
```

To:
```js
damage_matches_reported: device.damage_matches_reported != null ? !!device.damage_matches_reported : null,
```

This converts the raw value to a proper JSON boolean while preserving null. Consistent with how `data_backup_offered`, `is_under_warranty`, etc. are handled in the same response (~lines 855-863).

## Fix 2: iOS — iPad split view `.id()` modifier

When using `NavigationSplitView` on iPad, `DeviceDetailView` uses `@State` for its view model. Selecting a different device doesn't change the view's structural identity, so the `@State` retains the old device data and `.task` never re-fires. This causes stale data.

### File 1: `Repair Minder/Repair Minder/Features/Staff/Devices/DevicesView.swift`

In the `iPadBody` property, find the `DeviceDetailView` inside the detail pane and add `.id()`:

```swift
// Before
DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)

// After
DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)
    .id("\(nav.orderId)-\(nav.deviceId)")
```

### File 2: `Repair Minder/Repair Minder/Features/Staff/Dashboard/MyQueueView.swift`

Same change in its `iPadBody` property:

```swift
// Before
DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)

// After
DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)
    .id("\(nav.orderId)-\(nav.deviceId)")
```

## After making changes

1. Build the iOS app to confirm it compiles
2. Check the Xcode console for any `❌ DECODE ERROR` log lines when navigating to a device detail — the APIClient has debug logging at line 281-294 that prints the exact field and type causing any decode failures
