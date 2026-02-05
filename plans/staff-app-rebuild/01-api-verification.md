# Stage 01: Foundation & Networking

## Objective

Build the core networking infrastructure that all features depend on. This stage establishes the API client, response handling, and endpoint definitions.

---

## ⚠️ Pre-Implementation Verification

**Before writing any code, verify the following against the backend source files:**

1. **Response envelope structure** - Read any handler in `/Volumes/Riki Repos/repairminder/worker/` and confirm the `{ success, data, pagination?, error? }` pattern
2. **Pagination field names** - Verify `total_pages` vs `totalPages` in actual responses
3. **Token refresh endpoint** - Confirm `/api/auth/refresh` request/response shape in `src/auth.js`
4. **HTTP status codes** - Verify error handling matches `middleware/errorHandler.js`

```bash
# Quick verification commands
curl -s "https://api.repairminder.com/api/health" | jq  # Check API is live
grep -n "jsonResponse" /Volumes/Riki\ Repos/repairminder/worker/device_handlers.js | head -5  # Verify response pattern
```

**Do not proceed until you've verified the response shapes match this documentation.**

---

## API Response Envelope

All backend endpoints return a standard response wrapper:

```json
{
  "success": true | false,
  "data": T,
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "total_pages": 5
  },
  "error": "Error message if success=false"
}
```

**Notes:**
- `pagination` is optional (only on list endpoints)
- `error` is only present when `success: false`
- Backend returns `total_pages` in snake_case

---

## Endpoint Reference

### Auth Endpoints (`/api/auth/*`)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/login` | Initial login with email/password |
| POST | `/api/auth/2fa/request` | Request 2FA code via email |
| POST | `/api/auth/2fa/verify` | Verify 2FA code, get tokens |
| POST | `/api/auth/magic-link/request` | Request magic link code |
| POST | `/api/auth/magic-link/verify-code` | Verify 6-digit code |
| POST | `/api/auth/refresh` | Refresh access token |
| GET | `/api/auth/me` | Get current user + company |
| POST | `/api/auth/logout` | Logout, invalidate session |
| POST | `/api/auth/totp/setup` | Setup TOTP authenticator |
| POST | `/api/auth/totp/verify-setup` | Verify TOTP setup |
| POST | `/api/auth/totp/disable` | Disable TOTP |
| GET | `/api/auth/totp/status` | Get TOTP status |

### Customer Auth Endpoints (`/api/customer/auth/*`)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/customer/auth/request-magic-link` | Request customer login code |
| POST | `/api/customer/auth/verify-code` | Verify code, get customer token |
| GET | `/api/customer/auth/me` | Get current customer session |
| POST | `/api/customer/auth/logout` | Customer logout |

### Dashboard Endpoints (`/api/dashboard/*`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/dashboard/stats` | Device counts, revenue, comparisons |
| GET | `/api/dashboard/enquiry-stats` | Enquiry statistics |
| GET | `/api/dashboard/lifecycle` | Lifecycle metrics |
| GET | `/api/dashboard/category-breakdown` | Revenue by category |
| GET | `/api/dashboard/activity-log` | Recent activity feed |
| GET | `/api/dashboard/booking-heatmap` | Booking patterns |
| GET | `/api/dashboard/buyback-stats` | Buyback statistics |
| GET | `/api/dashboard/bookings-by-time` | Bookings over time |

### Devices Endpoints (`/api/devices/*`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/devices` | List all devices (company-wide) |
| GET | `/api/devices/my-queue` | Devices assigned to current user |
| GET | `/api/devices/my-active-work` | Active work for current user |
| GET | `/api/orders/:orderId/devices` | List devices for order |
| POST | `/api/orders/:orderId/devices` | Add device to order |
| GET | `/api/orders/:orderId/devices/:deviceId` | Get device detail |
| PATCH | `/api/orders/:orderId/devices/:deviceId` | Update device |
| DELETE | `/api/orders/:orderId/devices/:deviceId` | Delete device |
| PATCH | `/api/orders/:orderId/devices/:deviceId/status` | Update device status |
| GET | `/api/orders/:orderId/devices/:deviceId/actions` | Get available actions |
| POST | `/api/orders/:orderId/devices/:deviceId/action` | Execute action |

### Orders Endpoints (`/api/orders/*`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/orders` | List orders (paginated) |
| POST | `/api/orders` | Create order |
| GET | `/api/orders/:id` | Get order detail |
| PATCH | `/api/orders/:id` | Update order |
| GET | `/api/orders/:id/items` | List order items |
| POST | `/api/orders/:id/items` | Add order item |
| PATCH | `/api/orders/:id/items/:itemId` | Update order item |
| DELETE | `/api/orders/:id/items/:itemId` | Delete order item |
| GET | `/api/orders/:id/payments` | List payments |
| POST | `/api/orders/:id/payments` | Add payment |
| DELETE | `/api/orders/:id/payments/:paymentId` | Delete payment |
| GET | `/api/orders/:id/signatures` | List signatures |
| POST | `/api/orders/:id/signatures` | Capture signature |
| POST | `/api/orders/:id/send-quote` | Send quote to customer |
| POST | `/api/orders/:id/authorize` | Authorize order |
| POST | `/api/orders/:id/despatch` | Mark as despatched |
| POST | `/api/orders/:id/collect` | Mark as collected |

### Clients Endpoints (`/api/clients/*`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/clients` | List clients (paginated) |
| POST | `/api/clients` | Create client |
| GET | `/api/clients/:id` | Get client detail |
| PATCH | `/api/clients/:id` | Update client |
| DELETE | `/api/clients/:id` | Soft delete client |
| GET | `/api/clients/search` | Search clients |
| GET | `/api/clients/export` | Export clients |
| POST | `/api/clients/import` | Import clients |

### Tickets/Enquiries Endpoints (`/api/tickets/*`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/tickets` | List tickets (paginated) |
| POST | `/api/tickets` | Create ticket |
| GET | `/api/tickets/:id` | Get ticket detail |
| PATCH | `/api/tickets/:id` | Update ticket |
| POST | `/api/tickets/:id/reply` | Send reply |
| POST | `/api/tickets/:id/note` | Add internal note |
| POST | `/api/tickets/:id/resolve` | Resolve ticket |
| POST | `/api/tickets/:id/reassign` | Reassign ticket |
| POST | `/api/tickets/enquiry` | Create enquiry (public) |

### Push Notification Endpoints (`/api/user/*`)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/user/device-token` | Register device token |
| DELETE | `/api/user/device-token` | Unregister device token |
| GET | `/api/user/device-tokens` | List user's tokens |
| GET | `/api/user/push-preferences` | Get push preferences |
| PUT | `/api/user/push-preferences` | Update push preferences |

### Customer Portal Endpoints (`/api/customer/*`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/customer/orders` | List customer's orders |
| GET | `/api/customer/orders/:orderId` | Get order detail |
| POST | `/api/customer/orders/:orderId/approve` | Approve quote/device |
| POST | `/api/customer/orders/:orderId/reply` | Send message to shop |
| GET | `/api/customer/orders/:orderId/invoice` | Get invoice PDF |
| GET | `/api/customer/devices/:deviceId/images/:imageId/file` | Get device image |

### Configuration Endpoint (`/api/config`) - **FUTURE (Not Yet Implemented)**

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/config` | Get app configuration (public, no auth required) |

**⚠️ Important:** This endpoint does NOT exist in the backend yet. The iOS app MUST:
1. **Bundle a fallback `config.json`** with hardcoded values (see shape below)
2. Use the bundled fallback for all configuration data
3. When the backend endpoint is implemented, fetch and cache it

**Authentication:** Public endpoint - no auth required (when implemented).

**Future Behavior (when implemented):** Response will include `Cache-Control: public, max-age=86400` (24 hours). Mobile apps should:
1. Bundle a fallback `config.json` for offline use
2. Fetch on launch, cache locally
3. Compare `version` field to detect changes

**Response Shape:**

```json
{
  "version": "1.0.0",
  "generatedAt": "2026-02-04T10:30:00Z",

  "deviceStatuses": {
    "repair": [
      {
        "key": "device_received",
        "label": "Received",
        "customerLabel": "Device Received",
        "color": "gray",
        "isTerminal": false,
        "sortOrder": 0
      }
    ],
    "buyback": [
      {
        "key": "device_received",
        "label": "Received",
        "customerLabel": "Device Received",
        "color": "gray",
        "isTerminal": false,
        "sortOrder": 0
      }
    ]
  },

  "orderStatuses": [
    { "key": "awaiting_device", "label": "Awaiting Device", "sortOrder": 0 },
    { "key": "in_progress", "label": "In Progress", "sortOrder": 1 },
    { "key": "service_complete", "label": "Service Complete", "sortOrder": 2 },
    { "key": "awaiting_collection", "label": "Awaiting Collection/Despatch", "sortOrder": 3 },
    { "key": "collected_despatched", "label": "Collected/Despatched", "sortOrder": 4 }
  ],

  "workflows": ["repair", "buyback"],

  "paymentMethods": [
    { "key": "cash", "label": "Cash" },
    { "key": "card", "label": "Card" },
    { "key": "bank_transfer", "label": "Bank Transfer" },
    { "key": "paypal", "label": "PayPal" },
    { "key": "invoice", "label": "Invoice" },
    { "key": "other", "label": "Other" }
  ],

  "intakeMethods": [
    { "key": "walk_in", "label": "Walk-In" },
    { "key": "mail_in", "label": "Mail-In" },
    { "key": "courier", "label": "Courier" },
    { "key": "counter_sale", "label": "Counter Sale" },
    { "key": "accessories_in_store", "label": "Accessories In-Store" }
  ],

  "carriers": [
    { "key": "royal_mail", "label": "Royal Mail" },
    { "key": "dpd", "label": "DPD" },
    { "key": "dhl", "label": "DHL" },
    { "key": "ups", "label": "UPS" },
    { "key": "fedex", "label": "FedEx" },
    { "key": "evri", "label": "Evri" },
    { "key": "yodel", "label": "Yodel" },
    { "key": "other", "label": "Other" }
  ],

  "priorities": [
    { "key": "normal", "label": "Normal", "sortOrder": 0 },
    { "key": "urgent", "label": "Urgent", "sortOrder": 1 },
    { "key": "express", "label": "Express", "sortOrder": 2 }
  ],

  "conditionGrades": [
    { "key": "A", "label": "Grade A - Excellent", "description": "Like new condition" },
    { "key": "B", "label": "Grade B - Good", "description": "Minor wear" },
    { "key": "C", "label": "Grade C - Fair", "description": "Visible wear" },
    { "key": "D", "label": "Grade D - Poor", "description": "Significant wear" },
    { "key": "F", "label": "Grade F - Faulty", "description": "Not functional" }
  ],

  "accessoryTypes": [
    { "key": "charger", "label": "Charger" },
    { "key": "cable", "label": "Cable" },
    { "key": "case", "label": "Case" },
    { "key": "sim_card", "label": "SIM Card" },
    { "key": "stylus", "label": "Stylus" },
    { "key": "box", "label": "Box" },
    { "key": "sd_card", "label": "SD Card" },
    { "key": "other", "label": "Other" }
  ],

  "passcodeTypes": [
    { "key": "pin", "label": "PIN" },
    { "key": "pattern", "label": "Pattern" },
    { "key": "password", "label": "Password" },
    { "key": "biometric", "label": "Biometric" },
    { "key": "none", "label": "None" }
  ],

  "findMyStatuses": [
    { "key": "disabled", "label": "Disabled" },
    { "key": "enabled", "label": "Enabled" },
    { "key": "unknown", "label": "Unknown" }
  ],

  "imageTypes": [
    { "key": "pre_repair", "label": "Pre-Repair" },
    { "key": "post_repair", "label": "Post-Repair" },
    { "key": "damage", "label": "Damage" },
    { "key": "diagnostic", "label": "Diagnostic" },
    { "key": "part", "label": "Part" }
  ],

  "authorisationTypes": [
    { "key": "pre_authorised", "label": "Pre-Authorised" },
    { "key": "phone", "label": "Phone" },
    { "key": "email", "label": "Email" },
    { "key": "portal", "label": "Portal" }
  ],

  "ticketStatuses": [
    { "key": "open", "label": "Open" },
    { "key": "resolved", "label": "Resolved" },
    { "key": "closed", "label": "Closed" }
  ]
}
```

**Backend Source Files:**

| Data | File | Lines |
|------|------|-------|
| Device statuses (repair) | `worker/src/device-workflows.js` | 35-53 |
| Device statuses (buyback) | `worker/src/device-workflows.js` | 58-72 |
| Status labels | `worker/src/device-workflows.js` | 128-149 |
| Status colors | `worker/src/device-workflows.js` | 154-175 |
| Terminal statuses | `worker/src/device-workflows.js` | 334 |
| Order statuses | `worker/src/device-workflows.js` | 8-25 |
| Payment methods | `worker/order_handlers.js` | 37 |
| Intake methods | `worker/order_handlers.js` | 33 |
| Authorisation types | `worker/order_handlers.js` | 35 |
| Carriers | `worker/device_handlers.js` | 55 |
| Priorities | `worker/device_handlers.js` | 43 |
| Condition grades | `worker/device_handlers.js` | 53 |
| Accessory types | `worker/device_handlers.js` | 47 |
| Passcode types | `worker/device_handlers.js` | 49 |
| Find My statuses | `worker/device_handlers.js` | 51 |
| Image types | `worker/device_handlers.js` | 45 |

---

## Pagination Model

Backend pagination response fields:

| Field | Type | Notes |
|-------|------|-------|
| `page` | Int | Current page (1-indexed) |
| `limit` | Int | Items per page |
| `total` | Int | Total item count |
| `total_pages` | Int | Total page count |

**⚠️ Note:** Backend pagination field casing is inconsistent:
- Some handlers return `total_pages` (snake_case): orders, devices, macros
- Some handlers return `totalPages` (camelCase): clients, tickets, assets

Swift's `keyDecodingStrategy = .convertFromSnakeCase` handles both correctly, so use `totalPages` in Swift models.

---

## APIClient Requirements

### Base Configuration

```swift
let baseURL = URL(string: "https://api.repairminder.com")!
```

### Key Decoding Strategy

All responses use `snake_case` keys. Configure decoder:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
```

### Request Headers

```http
Authorization: Bearer <access_token>
Content-Type: application/json
User-Agent: RepairMinder-iOS/1.0 (iPhone; iOS 17.4)
```

**Important:** User-Agent must contain `Mobile`, `iPhone`, `iPad`, or similar to get 90-day refresh tokens (vs 7-day for web).

### Token Refresh Flow

On receiving HTTP 401:

1. Call `POST /api/auth/refresh` with body:
   ```json
   { "refreshToken": "opaque_refresh_token" }
   ```

2. Response:
   ```json
   {
     "token": "new_access_token",
     "refreshToken": "new_refresh_token",
     "expiresIn": 900
   }
   ```

3. Store new tokens, retry original request

4. If refresh fails, clear tokens and redirect to login

### Token Expiry

| Token | Web | Mobile |
|-------|-----|--------|
| Access Token | 15 min | 15 min |
| Refresh Token | 7 days | 90 days |

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Networking/APIResponse.swift` | Generic response wrapper + error type |
| `Core/Networking/APIClient.swift` | HTTP client with auth & retry logic |
| `Core/Networking/APIEndpoints.swift` | Endpoint enum definitions |
| `Core/Models/Pagination.swift` | Pagination model |

---

## Implementation Details

### APIResponse.swift

```swift
/// Standard API response wrapper
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let pagination: Pagination?
    let error: String?
}

/// Empty response for endpoints that return no data
struct EmptyResponse: Decodable {}
```

### Pagination.swift

```swift
struct Pagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int  // Decoded from total_pages
}
```

### APIClient.swift

Key responsibilities:
1. Manage base URL and session configuration
2. Inject `Authorization: Bearer` header from stored token
3. Handle 401 by calling refresh endpoint
4. Decode responses using snake_case strategy
5. Throw typed errors for non-success responses

### APIEndpoints.swift

Define as enum with associated values for parameters:

```swift
enum APIEndpoint {
    // Config (public, no auth)
    case config

    // Auth
    case login
    case twoFactorRequest
    case twoFactorVerify
    case magicLinkRequest
    case magicLinkVerifyCode
    case refreshToken
    case me
    case logout

    // Dashboard
    case dashboardStats(scope: String?, period: String?)
    case enquiryStats
    case lifecycle
    case categoryBreakdown
    case activityLog

    // Devices
    case devices(page: Int, limit: Int, status: String?)
    case myQueue
    case myActiveWork
    case orderDevices(orderId: String)
    case orderDevice(orderId: String, deviceId: String)
    case updateDeviceStatus(orderId: String, deviceId: String)
    case deviceActions(orderId: String, deviceId: String)
    case executeDeviceAction(orderId: String, deviceId: String)

    // Orders
    case orders(page: Int, limit: Int, status: String?)
    case order(id: String)
    case createOrder
    case updateOrder(id: String)
    case orderItems(orderId: String)
    case orderPayments(orderId: String)
    case orderSignatures(orderId: String)

    // Clients
    case clients(page: Int, limit: Int, search: String?)
    case client(id: String)
    case clientSearch(query: String)
    case createClient
    case updateClient(id: String)

    // Tickets
    case tickets(page: Int, limit: Int, status: String?)
    case ticket(id: String)
    case ticketReply(id: String)
    case ticketNote(id: String)

    // Push
    case registerDeviceToken
    case unregisterDeviceToken
    case pushPreferences
    case updatePushPreferences

    // Customer
    case customerMagicLinkRequest
    case customerVerifyCode
    case customerMe
    case customerLogout
    case customerOrders
    case customerOrder(orderId: String)
    case customerApproveQuote(orderId: String)
    case customerOrderReply(orderId: String)

    var path: String { /* return path string */ }
    var method: HTTPMethod { /* return method */ }
}
```

---

## Endpoint Testing Reference

> **Authoritative Sources for Token Management & D1 Queries:**
> - iOS Repo: [docs/REFERENCE-test-tokens/CLAUDE.md](../../docs/REFERENCE-test-tokens/CLAUDE.md)
> - Backend Repo: `/Volumes/Riki Repos/repairminder/docs/REFERENCE-test-tokens/CLAUDE.md`
>
> These files contain current valid test tokens, detailed token generation steps, D1 database access patterns, and troubleshooting guides.

### Quick Token Test

```bash
curl -s "https://api.repairminder.com/api/dashboard/stats" \
  -H "Authorization: Bearer <paste_token_directly>" | jq '.success'
```

**Important:** Paste tokens directly in curl commands. Shell variables truncate long JWT tokens.

---

## D1 Database Queries (via Wrangler)

All D1 queries must be run from the backend repo directory (`/Volumes/Riki Repos/repairminder`) or any directory with wrangler configured.

### Token Generation (Magic Link)

1. Request magic link:
   ```bash
   curl -s -X POST "https://api.repairminder.com/api/auth/magic-link/request" \
     -H "Content-Type: application/json" \
     -d '{"email": "rikibaker+admin@gmail.com"}'
   ```

2. Get code from database:
   ```bash
   npx wrangler d1 execute repairminder_database --remote --json \
     --command "SELECT magic_link_code FROM users WHERE email = 'rikibaker+admin@gmail.com'" \
     2>/dev/null | jq -r '.[0].results[0].magic_link_code'
   ```

3. Exchange for token:
   ```bash
   curl -s -X POST "https://api.repairminder.com/api/auth/magic-link/verify-code" \
     -H "Content-Type: application/json" \
     -d '{"email": "rikibaker+admin@gmail.com", "code": "XXXXXX"}' | jq -r '.data.token'
   ```

### 2FA Code Retrieval (for testing 2FA flow)

When testing the email-based 2FA login flow, retrieve the code from D1:

```bash
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT two_factor_code, two_factor_expires_at FROM users WHERE email = 'rikibaker+admin@gmail.com'" \
  2>/dev/null | jq -r '.[0].results[0]'
```

### Customer Portal Token Generation

1. Request customer magic link:
   ```bash
   curl -s -X POST "https://api.repairminder.com/api/customer/auth/request-magic-link" \
     -H "Content-Type: application/json" \
     -d '{"email": "rikibaker+customer@gmail.com"}'
   ```

2. Get code from clients table:
   ```bash
   npx wrangler d1 execute repairminder_database --remote --json \
     --command "SELECT magic_link_code FROM clients WHERE email = 'rikibaker+customer@gmail.com'" \
     2>/dev/null | jq -r '.[0].results[0].magic_link_code'
   ```

3. Exchange for customer token:
   ```bash
   curl -s -X POST "https://api.repairminder.com/api/customer/auth/verify-code" \
     -H "Content-Type: application/json" \
     -d '{"email": "rikibaker+customer@gmail.com", "code": "XXXXXX"}' | jq -r '.data.token'
   ```

### Push Notification Debugging

Verify device token registration:

```bash
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT * FROM device_tokens WHERE user_id = '<USER_ID>' ORDER BY created_at DESC LIMIT 5" \
  2>/dev/null | jq '.[0].results'
```

Check push notification delivery logs (no API endpoint for this):

```bash
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT * FROM push_notification_log WHERE user_id = '<USER_ID>' ORDER BY created_at DESC LIMIT 10" \
  2>/dev/null | jq '.[0].results'
```

Verify push preferences were saved:

```bash
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT * FROM push_notification_preferences WHERE user_id = '<USER_ID>'" \
  2>/dev/null | jq '.[0].results[0]'
```

### General D1 Query Pattern

```bash
# Basic query
npx wrangler d1 execute repairminder_database --remote --command "YOUR_SQL"

# JSON output (for parsing)
npx wrangler d1 execute repairminder_database --remote --json --command "YOUR_SQL"

# List all tables
npx wrangler d1 execute repairminder_database --remote \
  --command "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
```

---

## Verification Checklist

- [ ] Build succeeds with no errors
- [ ] `APIResponse<T>` decodes standard envelope correctly
- [ ] `Pagination` decodes with `totalPages` from `total_pages`
- [ ] `APIClient` injects Authorization header
- [ ] `APIClient` handles 401 with token refresh
- [ ] `APIClient` retries request after successful refresh
- [ ] `APIClient` clears tokens and throws on refresh failure
- [ ] snake_case keys convert to camelCase properties
- [ ] Test request to `/api/auth/me` returns user data

---

## Error Handling

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (validation error) |
| 401 | Unauthorized (invalid/expired token) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found |
| 429 | Rate Limited |
| 500 | Server Error |

### Quarantine Mode

Users from companies with `status='pending_approval'` or `status='suspended'` get a 403 with:

```json
{
  "success": false,
  "error": "Your account is pending approval...",
  "code": "ACCOUNT_PENDING_APPROVAL"
}
```

---

## Next Stage

Once networking is verified, proceed to **Stage 02: Authentication** to implement the full login flow.
