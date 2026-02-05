# iOS Unified App Rebuild - Master Plan

## Feature Overview

### What
Complete rebuild of the iOS app as a **single unified app target** supporting both **Staff** and **Customer** roles. Users select their role at login, and the app shows the appropriate interface:
- **Staff**: Dashboard, devices, orders, enquiries, settings
- **Customer**: Order list, order detail with quote approval, messaging

### Why
The original iOS app was built without verifying backend API endpoints, causing:
- JSON decoding failures ("Failed to decode response")
- Features that silently fail or show no data
- Endpoints calling paths that don't exist
- Request/response format mismatches with snake_case vs camelCase

Additionally, having separate Staff and Customer app targets created unnecessary duplication. A unified app:
- **Single app target** - `Repair Minder` handles both roles
- Shares models, networking, and components
- Single App Store presence
- Simpler maintenance and deployment
- Backend already supports both auth flows

---

## Core Methodology: Web App as Source of Truth

**CRITICAL**: The web app at `/Volumes/Riki Repos/repairminder` is the **single source of truth** for all API implementation.

### The Rule
> **Never duplicate API specs in documentation. Always read from the backend source files.**

### For Each Feature Implementation:
1. **Read the handler file** in `/Volumes/Riki Repos/repairminder/worker/` to understand the endpoint
2. **Find the response shape** by reading what the handler returns
3. **Build Swift models** that match the actual response structure
4. **Test against the running backend** to verify

### ⚠️ Mandatory Verification Step
Each stage document includes a **Pre-Implementation Verification** section. Workers MUST:
- Run the verification commands listed
- Confirm response shapes match the documentation
- Report any discrepancies before proceeding

This catches backend changes that may have occurred since the plan was written.

### Why This Matters
- Documentation gets stale; source code is always current
- The backend is actively maintained; any changes are immediately visible
- No translation errors from "what we think the API does" vs "what it actually does"

---

## Backend File Reference (Actual Locations)

All iOS implementation should read from: `/Volumes/Riki Repos/repairminder/worker/`

### Handler Files by Feature

| Feature | Backend File | How to Find Response Shape |
|---------|--------------|---------------------------|
| **Staff Auth** | `src/auth.js` | Look for `login()`, `_issueTokenPair()` methods |
| **Customer Auth** | `src/customer-auth.js` | Look for magic link request/verify functions |
| **Auth Routes** | `index.js` (lines 1435+) | Search for `/api/auth` to see all auth endpoints |
| **Dashboard** | `dashboard_handlers.js` | Search for `getStats`, `getEnquiryStats` |
| **Devices** | `device_handlers.js` | Search for response objects returned |
| **Device Workflows** | `src/device-workflows.js` | Contains all status definitions and transitions |
| **Orders** | `order_handlers.js` | Search for `getOrder`, `getOrders` functions |
| **Clients** | `client_handlers.js` | Search for response construction |
| **Tickets/Enquiries** | `ticket_handlers.js` | Search for `getTicket`, message handling |
| **Ticket AI** | `src/ticket_llm_handlers.js` | AI response generation |
| **Macros/Workflows** | `macro_execution_handlers.js` | Workflow execution |
| **Push Notifications** | `device_token_handlers.js` | Token registration, preferences |
| **Authorization** | `authorization_handlers.js` | Quote approval endpoints |
| **Customer Orders** | `order_handlers.js` | Search for `/api/customer/` routes in `index.js` |

### How to Read a Handler File

Example for devices - in `device_handlers.js`, look for patterns like:

```javascript
// Find the list response shape
return jsonResponse({
  success: true,
  data: devices,  // <-- This tells you the response structure
  pagination: { ... }
});

// Find the detail response shape
return jsonResponse({
  success: true,
  data: device  // <-- Read what fields are in 'device'
});
```

### Finding Routes

All routes are defined in `index.js`. Search for the path pattern:
```javascript
case path === '/api/devices':
case path.startsWith('/api/devices/'):
case path === '/api/customer/orders':
```

---

## Key Business Logic (Read from Source)

These rules come from the backend and must be respected:

| Rule | Source File | What to Read |
|------|-------------|--------------|
| Device status transitions | `src/device-workflows.js` | `getNextStatuses()` function |
| Order status calculation | `order_handlers.js` | Status is auto-calculated from devices |
| Push notification format | `device_token_handlers.js` | Required fields: `platform`, `app_type` |
| Response envelope | All handlers | `{ success, data, pagination?, error? }` |
| Field naming | All handlers | Always `snake_case` from backend |

---

## Step 0: Pre-Implementation Setup

Before starting any stage:

### 1. Verify Backend Access

```bash
# Ensure web app exists
ls /Volumes/Riki\ Repos/repairminder/worker/

# Key files should exist:
ls /Volumes/Riki\ Repos/repairminder/worker/src/auth.js
ls /Volumes/Riki\ Repos/repairminder/worker/device_handlers.js
ls /Volumes/Riki\ Repos/repairminder/worker/order_handlers.js
```

### 2. Test Backend is Running

```bash
# Test staff auth (read src/auth.js for expected response)
curl -X POST http://localhost:8787/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test"}'

# Test with token (read dashboard_handlers.js for response shape)
curl http://localhost:8787/api/dashboard/stats \
  -H "Authorization: Bearer {token}"
```

### 3. Clean iOS Project

```bash
# Remove existing broken code (skip if already cleaned)
rm -rf "Repair Minder/Repair Minder/Core/Models/"
rm -rf "Repair Minder/Repair Minder/Core/Networking/"
rm -rf "Repair Minder/Repair Minder/Core/Auth/"
rm -rf "Repair Minder/Repair Minder/Features/"
rm -rf "Repair Minder/Customer/"
```

**After cleanup, your project should have:**
- `Core/` - empty directory (ready for new networking/auth code)
- `Resources/config.json` - bundled fallback configuration
- `Assets.xcassets/` - app icons and images
- `Repair_MinderApp.swift` - main app entry point

**Verify cleanup:**
```bash
ls "Repair Minder/Repair Minder/"
# Should show: Assets.xcassets, Configuration, Core, Resources, *.swift files
```

---

## Stage Index

Each stage reads from specific backend files to build the iOS implementation.

| Stage | Name | Read From | What to Build |
|-------|------|-----------|---------------|
| **01** ✅ | Foundation | `index.js`, all handlers | APIClient, APIResponse, base networking |
| **02** ✅ | Authentication | `src/auth.js`, `src/customer-auth.js` | AuthManager, login flows for both roles |
| **03** ✅ | Dashboard & My Queue | `dashboard_handlers.js`, `device_handlers.js` | Dashboard stats, my queue list |
| **04** ✅ | Devices & Scanner | `device_handlers.js`, `src/device-workflows.js` | Device list/detail, status transitions |
| **05** ✅ | Orders & Clients | `order_handlers.js`, `client_handlers.js` | Order/client list and detail views |
| **06** ✅ | Enquiries | `ticket_handlers.js`, `src/ticket_llm_handlers.js` | Ticket list, messages, replies |
| **07** ✅ | Settings & Push | `device_token_handlers.js`, `company_handlers.js` | Push registration, preferences |
| **08** ✅ | Customer Screens | `order_handlers.js`, `authorization_handlers.js` | Customer orders, quote approval |
| **09** ✅ | Integration Testing | All handlers | End-to-end verification |

### Stage Dependencies

```
Stage 01 ──> Stage 02 ──┬──> Stage 03 (Dashboard)
                        ├──> Stage 04 (Devices)
                        ├──> Stage 05 (Orders & Clients)
                        ├──> Stage 06 (Enquiries)
                        ├──> Stage 07 (Settings & Push)
                        └──> Stage 08 (Customer Screens)
                                       │
                        All Stages ────┴──> Stage 09 (Integration)
```

---

## Implementation Pattern for Each Stage

### Step 1: Read the Backend Handler

```bash
# Example: Building device feature
# Read the handler to understand response shape
cat /Volumes/Riki\ Repos/repairminder/worker/device_handlers.js | head -500
```

Look for:
- What fields are returned in `data`
- What nested objects exist
- What enums/status values are used
- What query parameters are accepted

### Step 2: Read the Routes

```bash
# Find all device routes
grep -n "device" /Volumes/Riki\ Repos/repairminder/worker/index.js | head -50
```

### Step 3: Build Swift Models

Create models that **exactly match** what you read in the handler:
- Use optional types for nullable fields
- Match field names (Swift decoder converts snake_case)
- Include all nested types

### Step 4: Test Against Running Backend

```bash
# Hit the actual endpoint
curl http://localhost:8787/api/devices \
  -H "Authorization: Bearer {token}" | jq .
```

Compare the actual response to your Swift model.

---

## Success Criteria

| Criteria | Verification |
|----------|--------------|
| Zero decode errors | No "keyNotFound", "typeMismatch" in console |
| Models match backend | Compare Swift properties to handler response |
| All endpoints work | Test each endpoint with curl first |
| Role selection works | Staff and Customer can both login |
| Push notifications | Token registers with correct `app_type` |

---

## iOS App Structure

```
Repair Minder/Repair Minder/
├── App/
│   ├── AppDelegate.swift
│   ├── AppState.swift
│   ├── UserRole.swift
│   └── Repair_MinderApp.swift
├── Core/
│   ├── Auth/
│   │   ├── AuthManager.swift       # Read: src/auth.js, src/customer-auth.js
│   │   └── KeychainManager.swift
│   ├── Models/                     # Read: Each handler's response shape
│   │   ├── Device.swift            # Read: device_handlers.js
│   │   ├── DeviceStatus.swift      # Read: src/device-workflows.js
│   │   ├── Order.swift             # Read: order_handlers.js
│   │   ├── Ticket.swift            # Read: ticket_handlers.js
│   │   ├── Client.swift            # Read: client_handlers.js
│   │   ├── DashboardStats.swift    # Read: dashboard_handlers.js
│   │   └── User.swift              # Read: src/auth.js
│   ├── Networking/
│   │   ├── APIClient.swift         # snake_case decoder, auth interceptor
│   │   ├── APIEndpoints.swift      # Read: index.js for all routes
│   │   └── APIResponse.swift       # Standard {success, data, pagination}
│   └── Notifications/
│       └── PushNotificationManager.swift  # Read: device_token_handlers.js
├── Features/
│   ├── Auth/
│   ├── Staff/
│   │   ├── Dashboard/
│   │   ├── Devices/
│   │   ├── Scanner/
│   │   ├── Orders/
│   │   ├── Clients/
│   │   └── Enquiries/
│   ├── Customer/
│   │   ├── OrderList/
│   │   ├── OrderDetail/
│   │   └── QuoteApproval/
│   └── Settings/
└── Shared/
    └── Components/
```

---

## Out of Scope

| Item | Reason |
|------|--------|
| Booking Feature | Separate plan in `plans/new-booking-feature/` |
| Offline Mode | Removed, staying online-only |
| Unit Tests | After rebuild |
| UI Polish | Focus on functionality first |
| Payment Processing | Web-only |

---

## 🔄 Dynamic Configuration (Future)

Some values are currently hardcoded in Swift but should eventually be fetched from a `/api/config` endpoint:

| Item | Current Location | Notes |
|------|-----------------|-------|
| Device statuses (labels, colors) | `DeviceStatus.swift` | Design code to support dynamic updates |
| Status transitions | `DeviceStatus.swift` | Backend validates, but iOS shows available actions |
| Customer progress stages | Customer screens | Maps internal statuses to customer-facing labels |

A separate task will add `GET /api/config` to the backend. Until then, hardcode initial values but structure code to accept dynamic configuration.

---

## Quick Reference: Finding Things in Backend

### Auth Endpoints
```bash
grep -n "/api/auth" /Volumes/Riki\ Repos/repairminder/worker/index.js
```

### Customer Endpoints
```bash
grep -n "/api/customer" /Volumes/Riki\ Repos/repairminder/worker/index.js
```

### Device Statuses
```bash
cat /Volumes/Riki\ Repos/repairminder/worker/src/device-workflows.js | grep -A5 "statuses"
```

### Any Handler Response Shape
```bash
# Look for jsonResponse or return statements
grep -n "jsonResponse\|return.*success" /Volumes/Riki\ Repos/repairminder/worker/{handler_name}.js
```

---

## Verification Commands

### Build
```bash
xcodebuild -project "Repair Minder/Repair Minder.xcodeproj" \
  -scheme "Repair Minder" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  build
```

### Runtime
1. Launch app in Simulator
2. Login with test credentials
3. Monitor Xcode console for decode errors
4. Navigate through all features
5. Compare displayed data to curl responses

---

## Remember

> **The web app is the source of truth. When in doubt, read the handler file.**

Don't guess what an API returns. Don't copy from documentation. Open the handler file, read what it returns, and build your Swift model to match exactly.
