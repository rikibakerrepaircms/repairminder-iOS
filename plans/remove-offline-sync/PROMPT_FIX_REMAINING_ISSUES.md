# Prompt: Fix Remaining iOS App Issues

## Context

We removed Core Data/offline sync from the RepairMinder iOS app. During testing, we found and fixed several issues (API response mismatches, white screens on detail views, wrong navigation). However, 3 issues remain that are feature gaps or backend issues.

**Reference Document:** `plans/remove-offline-sync/POST_REMOVAL_ISSUES.md`

---

## Issue 1: Dashboard Stat Cards Not Tappable

**Priority:** Medium

**Current Behavior:** The stat cards on the dashboard (Devices, Revenue, Clients, New Clients) are display-only and don't respond to taps.

**Expected Behavior:** Tapping a stat card should navigate to the relevant section:
- Devices card → Devices list
- Revenue card → Orders list (or revenue details)
- Clients card → Clients list
- New Clients card → Clients list (filtered to new)

**Files to Modify:**
- `Repair Minder/Features/Dashboard/Components/StatCard.swift` - Add tap handler/destination
- `Repair Minder/Features/Dashboard/DashboardView.swift` - Pass navigation actions to StatsGridView

**Implementation Approach:**
1. Add an optional `destination: AppRoute?` or `onTap: (() -> Void)?` parameter to `StatCard`
2. Wrap the card content in a `Button` or add `.onTapGesture`
3. In `StatsGridView`, pass the appropriate navigation for each card
4. Use `router.navigate(to: .devices)`, `router.selectedTab = .orders`, etc.

---

## Issue 2: New Order Button Not Working

**Priority:** High

**Current Behavior:** The "New Order" quick action button on the dashboard just switches to the Orders tab (`router.selectedTab = .orders`).

**Expected Behavior:** Should open an order creation/booking flow.

**File:** `Repair Minder/Features/Dashboard/Components/QuickActionsView.swift`

**Current Code (line 23-25):**
```swift
QuickActionButton(
    title: "New Order",
    icon: "plus.circle.fill",
    color: .blue
) {
    router.selectedTab = .orders
}
```

**Options:**
1. **Option A - Full Implementation:** Create a new `CreateOrderView` with a form for:
   - Client selection/creation
   - Device details
   - Issue description
   - Estimated price
   This requires new views, view models, and API integration.

2. **Option B - Web Redirect:** Open the web app's booking page in Safari:
   ```swift
   if let url = URL(string: "https://app.repairminder.com/orders/new") {
       UIApplication.shared.open(url)
   }
   ```

3. **Option C - Sheet Placeholder:** Show a sheet explaining the feature is coming soon, with a button to open the web app.

**Recommendation:** Start with Option B or C as a quick fix, then implement Option A as a follow-up task.

---

## Issue 3: Settings > Notifications Not Working

**Priority:** Medium

**Current Behavior:** The notifications settings screen shows "Failed to load notification settings" error.

**Root Cause:** The backend API endpoint `/api/user/push-preferences` returns an error:
```json
{"error": "Failed to get push preferences"}
```

**This is a BACKEND issue, not an iOS issue.**

**Files for Reference:**
- `Repair Minder/Features/Settings/NotificationSettingsView.swift` - The iOS view (works correctly)
- Backend: `worker/src/user-handlers.js` - Likely location of the endpoint

**Backend Investigation Needed:**
1. Check if the `push-preferences` endpoint exists in the backend
2. Check if the user has the necessary permissions
3. Check if the database table for push preferences exists
4. Check if there's an auth/token issue

**iOS Workaround (Optional):**
If the backend can't be fixed immediately, add graceful error handling:
```swift
// In NotificationSettingsViewModel.loadPreferences()
} catch {
    // Show default preferences instead of error
    logger.warning("Using default preferences - API unavailable")
    preferences = .defaultPreferences
}
```

---

## Testing Instructions

After making changes:

1. Build the app: `xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

2. Run in simulator and test:
   - Dashboard stat cards respond to taps and navigate correctly
   - "New Order" button performs the expected action
   - Settings > Notifications loads (or shows appropriate fallback)

3. Test with different user accounts to ensure permissions work correctly

---

## API Reference

**Login for testing:**
- Email: `riki+repairminder@mendmyi.com` (mendmyi admin)
- Or: `rikibaker+admin@gmail.com` (repairminder admin)

**Token generation:** See `docs/REFERENCE-test-tokens/CLAUDE.md`

**API Base URL:** `https://api.repairminder.com`

---

## Files Overview

```
Repair Minder/
├── Features/
│   ├── Dashboard/
│   │   ├── Components/
│   │   │   ├── StatCard.swift          # Issue 1: Add tap handling
│   │   │   ├── QuickActionsView.swift  # Issue 2: Fix New Order action
│   │   │   └── MyQueueSection.swift    # Already fixed
│   │   └── DashboardView.swift         # Issue 1: Pass nav actions
│   └── Settings/
│       └── NotificationSettingsView.swift  # Issue 3: Add fallback
├── App/
│   └── AppRouter.swift                 # Navigation routes
└── Core/
    └── Networking/
        └── APIEndpoints.swift          # API endpoint definitions
```
