# Post Core Data Removal - Issues Found

**Date**: 2026-02-04
**Tested by**: User (riki+repairminder@mendmyi.com - admin for mendmyi)
**Build Status**: Compiles successfully

## Issues Found & Fixes Applied

### 1. Clients List Not Loading
- **Status**: FIXED
- **Symptom**: Shows "No Clients" empty state even though API returns clients
- **Root Cause**: API returns `{ clients: [], pagination: {} }` but ViewModel expected `[Client]` directly
- **Fix**: Updated `ClientListViewModel.swift` to use `ClientsResponse` wrapper that matches API format
- **File**: `Features/Clients/ClientListViewModel.swift`

### 2. Enquiries List Not Loading
- **Status**: FIXED
- **Symptom**: Shows empty state, loads nothing
- **Root Cause**:
  1. API endpoint was `/api/enquiries` but should be `/api/tickets`
  2. API returns `{ tickets: [], page, totalPages, ... }` not `{ items: [], pagination: {} }`
- **Fix**:
  1. Updated `APIEndpoints.swift` to use `/api/tickets` paths
  2. Updated `EnquiriesResponse` struct to match API format
- **Files**:
  - `Core/Networking/APIEndpoints.swift`
  - `Features/Enquiries/EnquiryListViewModel.swift`

### 3. Order Detail - White Screen
- **Status**: FIXED
- **Symptom**: Tapping on an order shows white/blank screen
- **Root Cause**: `isLoading` initialized to `false`, so before `.task` runs there's a moment where nothing displays
- **Fix**: Changed `isLoading` initial value to `true` in `OrderDetailViewModel`
- **File**: `Features/Orders/OrderDetailViewModel.swift`

### 4. Device Detail - White Screen
- **Status**: FIXED
- **Symptom**: Tapping on a device shows white/blank screen
- **Root Cause**: Same as Order Detail - `isLoading` started as `false`
- **Fix**: Changed `isLoading` initial value to `true` in `DeviceDetailViewModel`
- **File**: `Features/Devices/DeviceDetailViewModel.swift`

### 5. Dashboard Stat Cards Not Tappable
- **Status**: FEATURE GAP (Not implemented)
- **Symptom**: The figures in the dashboard stat boxes don't respond to taps
- **Analysis**: `StatCard` component is display-only, has no tap handlers
- **Required**: Add navigation actions to stat cards (e.g., tap Devices -> navigate to Devices list)
- **Priority**: Medium - Enhancement request, not a bug

### 6. New Order Button Not Working
- **Status**: FEATURE GAP (Not implemented)
- **Symptom**: "New Order" quick action doesn't bring up the booking page
- **Analysis**: Current implementation just switches to Orders tab (`router.selectedTab = .orders`)
- **Required**: Implement order creation flow/modal
- **Priority**: High - Core feature missing

### 7. My Queue "See All" Button Wrong Navigation
- **Status**: FIXED
- **Symptom**: "See All" button on My Queue section takes user to Orders instead of Devices
- **Root Cause**: Button action was `router.selectedTab = .orders` instead of navigating to devices
- **Fix**: Changed to `router.navigate(to: .devices)`
- **File**: `Features/Dashboard/Components/MyQueueSection.swift`

### 8. Settings > Notifications Not Working
- **Status**: BACKEND ISSUE
- **Symptom**: Notifications settings screen fails to load
- **Analysis**: API endpoint `/api/user/push-preferences` returns error: `{"error": "Failed to get push preferences"}`
- **Required**: Backend fix needed for push preferences endpoint
- **Priority**: Medium - Backend team needs to investigate

## Additional Fixes Applied

### Client/Enquiry Detail Views
- Fixed `isLoading` initialization in `ClientDetailViewModel.swift`
- Fixed `isLoading` initialization in `EnquiryDetailViewModel.swift`

## What IS Working

- Dashboard loads and displays stats
- Orders list loads and displays orders
- Order details (after fix)
- Device details (after fix)
- Clients list (after fix)
- Enquiries list (after fix)
- Login/authentication flow
- Tab bar navigation
- Recent Orders on dashboard
- My Queue on dashboard
- Scanner (navigation works)

## Root Cause Analysis Summary

The main issues fall into these categories:

1. **API Response Format Mismatches**: The app expected different JSON structures than what the API returns. The API wraps responses in objects with specific keys (e.g., `clients`, `tickets`) rather than returning arrays directly.

2. **Initial State Issues**: Detail ViewModels started with `isLoading = false`, causing a brief white screen before the `.task` modifier runs the async data loading.

3. **Wrong API Endpoints**: The enquiries feature was calling `/api/enquiries` but the API uses `/api/tickets`.

4. **Navigation Bugs**: Some buttons had incorrect navigation targets (e.g., My Queue "See All" going to Orders instead of Devices).

5. **Feature Gaps**: Some features (stat card navigation, new order creation) were never fully implemented.

6. **Backend Issues**: Push preferences endpoint returns an error - needs backend investigation.

## Files Modified

1. `Features/Orders/OrderDetailViewModel.swift` - isLoading = true
2. `Features/Devices/DeviceDetailViewModel.swift` - isLoading = true
3. `Features/Clients/ClientDetailViewModel.swift` - isLoading = true
4. `Features/Clients/ClientListViewModel.swift` - Added ClientsResponse wrapper
5. `Features/Enquiries/EnquiryDetailViewModel.swift` - isLoading = true
6. `Features/Enquiries/EnquiryListViewModel.swift` - Fixed EnquiriesResponse format
7. `Core/Networking/APIEndpoints.swift` - Changed /api/enquiries to /api/tickets
8. `Features/Dashboard/Components/MyQueueSection.swift` - Fixed See All navigation

## Remaining Work (Not Related to Core Data Removal)

1. **New Order Flow**: Implement order creation UI and flow
2. **Stat Card Navigation**: Add tap handlers to dashboard stat cards
3. **Backend Fix**: Fix `/api/user/push-preferences` endpoint
