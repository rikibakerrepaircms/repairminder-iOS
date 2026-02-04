# iOS App API Verification Document

## Overview
This document compares every iOS model against the actual backend API responses to identify mismatches causing JSON decoding failures.

**Current Issues:**
- Sync errors with "Failed to decode response: The data couldn't be read because it isn't in the correct format"
- Settings > Notifications "failed to load notification settings"
- Orders, Clients, Dashboard loading nothing

**Root Cause:** iOS models expect different field names and structures than what the backend actually returns.

---

## Critical Configuration

### APIClient Settings
**File:** `Core/Networking/APIClient.swift`
```swift
decoder.keyDecodingStrategy = .convertFromSnakeCase  // Converts snake_case to camelCase
decoder.dateDecodingStrategy = .iso8601
```

### Standard Response Wrapper
**File:** `Core/Networking/APIResponse.swift`
Backend wraps most responses in:
```json
{
  "success": true,
  "data": { ... actual data ... }
}
```

---

## Model Comparisons

### 1. Device Model - CRITICAL MISMATCH

**iOS Model Location:** `Core/Models/Device.swift`

| iOS Field | iOS Type | Backend Field | Backend Type | Status |
|-----------|----------|---------------|--------------|--------|
| id | String | id | String | OK |
| orderId | String | order_id | String | OK |
| type | String | - | - | MISSING in backend |
| brand | String? | - | - | MISSING in backend |
| model | String? | - | - | MISSING in backend |
| serial | String? | serial_number | String | WRONG NAME |
| imei | String? | imei | String | OK |
| passcode | String? | - | - | MISSING in backend |
| status | DeviceStatus | status | String | OK |
| issue | String? | - | - | MISSING in backend |
| diagnosis | String? | - | - | MISSING in backend |
| resolution | String? | - | - | MISSING in backend |
| price | Decimal? | - | - | MISSING in backend |
| assignedUserId | String? | assigned_engineer.id | Object | WRONG STRUCTURE |
| assignedUserName | String? | assigned_engineer.name | Object | WRONG STRUCTURE |
| createdAt | Date | created_at | String | OK |
| updatedAt | Date | - | - | MISSING in backend |

**Actual Backend Response (from device_handlers.js:2903-2943):**
```json
{
  "id": "uuid",
  "order_id": "uuid",
  "ticket_id": "uuid",
  "order_number": 12345,
  "client_first_name": "John",
  "client_last_name": "Doe",
  "display_name": "Apple iPhone 14 Pro",
  "serial_number": "ABC123",
  "imei": "123456789",
  "colour": "Black",
  "status": "received",
  "workflow_type": "repair",
  "device_type": {
    "id": "uuid",
    "name": "Phone",
    "slug": "repair"
  },
  "assigned_engineer": {
    "id": "uuid",
    "name": "John Smith"
  },
  "location_id": "uuid",
  "sub_location_id": "uuid",
  "sub_location": {
    "id": "uuid",
    "code": "A1",
    "description": "Shelf A1",
    "type": "shelf",
    "location_id": "uuid"
  },
  "received_at": "2026-02-04T10:00:00.000Z",
  "due_date": "2026-02-07T10:00:00.000Z",
  "created_at": "2026-02-04T10:00:00.000Z",
  "notes": [],
  "source": "order"
}
```

**FIX REQUIRED:**
```swift
struct Device: Identifiable, Equatable, Sendable, Decodable {
    let id: String
    let orderId: String?
    let ticketId: String?
    let orderNumber: Int?
    let clientFirstName: String?
    let clientLastName: String?
    let displayName: String
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let status: DeviceStatus
    let workflowType: String?
    let deviceType: DeviceTypeInfo?
    let assignedEngineer: AssignedEngineer?
    let locationId: String?
    let subLocationId: String?
    let subLocation: SubLocation?
    let receivedAt: Date?
    let dueDate: Date?
    let createdAt: Date
    let notes: [DeviceNote]?
    let source: String?

    struct DeviceTypeInfo: Decodable, Equatable, Sendable {
        let id: String
        let name: String
        let slug: String
    }

    struct AssignedEngineer: Decodable, Equatable, Sendable {
        let id: String
        let name: String
    }

    struct SubLocation: Decodable, Equatable, Sendable {
        let id: String
        let code: String?
        let description: String?
        let type: String?
        let locationId: String?
    }

    struct DeviceNote: Decodable, Equatable, Sendable {
        let body: String?
        let createdAt: Date?
        let createdBy: String?
        let deviceId: String?
    }
}
```

---

### 2. Client Model - CRITICAL MISMATCH

**iOS Model Location:** `Core/Models/Client.swift`

| iOS Field | iOS Type | Backend Field | Backend Type | Status |
|-----------|----------|---------------|--------------|--------|
| id | String | id | String | OK |
| email | String | email | String | OK |
| firstName | String? | first_name | String | OK |
| lastName | String? | last_name | String | OK |
| phone | String? | phone | String | OK |
| company | String? | - | - | MISSING |
| address | String? | - | - | MISSING (see address_line_1) |
| city | String? | - | - | MISSING |
| postcode | String? | - | - | MISSING |
| notes | String? | - | - | MISSING |
| orderCount | Int | order_count | Int | OK |
| totalSpent | Decimal | total_spend | Double | WRONG NAME |
| createdAt | Date | created_at | String | OK |
| updatedAt | Date | - | - | MISSING |

**Actual Backend Response (from client_handlers.js:211-250):**
```json
{
  "id": "uuid",
  "email": "john@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1234567890",
  "country_code": "GB",
  "client_group_id": "uuid",
  "client_group_name": "VIP",
  "groups": [
    { "id": "uuid", "name": "VIP", "group_type": "manual" }
  ],
  "email_suppressed": false,
  "email_suppressed_at": null,
  "is_generated_email": false,
  "marketing_consent": true,
  "suppression_status": null,
  "suppression_error": null,
  "ticket_count": 5,
  "order_count": 10,
  "device_count": 15,
  "total_spend": 1234.56,
  "average_spend": 123.46,
  "last_contact_received": "2026-02-04T10:00:00.000Z",
  "last_contact_sent": "2026-02-04T10:00:00.000Z",
  "created_at": "2026-01-01T10:00:00.000Z"
}
```

**FIX REQUIRED:**
```swift
struct Client: Identifiable, Equatable, Sendable, Decodable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let phone: String?
    let countryCode: String?
    let clientGroupId: String?
    let clientGroupName: String?
    let groups: [ClientGroup]?
    let emailSuppressed: Bool?
    let emailSuppressedAt: Date?
    let isGeneratedEmail: Bool?
    let marketingConsent: Bool?
    let ticketCount: Int
    let orderCount: Int
    let deviceCount: Int
    let totalSpend: Double
    let averageSpend: Double?
    let lastContactReceived: Date?
    let lastContactSent: Date?
    let createdAt: Date

    struct ClientGroup: Decodable, Equatable, Sendable {
        let id: String
        let name: String
        let groupType: String?
    }
}
```

---

### 3. Ticket Model - NEEDS VERIFICATION

**iOS Model Location:** `Core/Models/Ticket.swift`

The backend returns tickets in a different structure than expected.

**Actual Backend Response (from ticket_handlers.js:215-245):**
```json
{
  "id": "uuid",
  "ticket_number": 12345,
  "subject": "Screen Repair",
  "status": "open",
  "ticket_type": "order",
  "assigned_user_id": "uuid",
  "location_id": "uuid",
  "created_at": "2026-02-04T10:00:00.000Z",
  "updated_at": "2026-02-04T10:00:00.000Z",
  "client_id": "uuid",
  "client_email": "john@example.com",
  "client_name": "John Doe",
  "assigned_first_name": "Jane",
  "assigned_last_name": "Smith",
  "loc_id": "uuid",
  "loc_name": "Main Store",
  "last_client_update": "2026-02-04T10:00:00.000Z",
  "order_id": "uuid",
  "order_status": "in_progress",
  "device_count": 2
}
```

**iOS Issues:**
- `priority` field expected but not returned
- `orderRef` expected but not returned
- `messageCount` expected but `device_count` is returned
- `assignedUserName` expected but separate first/last name fields returned
- Backend uses `client_name` (not separate client_email/client_name structure)

---

### 4. Order Model - MOSTLY OK

**iOS Model Location:** `Core/Models/Order.swift`

The Order model appears to be correctly structured after recent updates. However, verify these nested objects:

**Backend Response includes:**
```json
{
  "id": "uuid",
  "order_number": 12345,
  "status": "in_progress",
  "order_total": "150.00",
  "amount_paid": "50.00",
  "balance_due": "100.00",
  "notes": "Customer notes",
  "device_count": 2,
  "created_at": "2026-02-04T10:00:00.000Z",
  "updated_at": "2026-02-04T10:00:00.000Z",
  "client": {
    "id": "uuid",
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "phone": "+1234567890"
  },
  "location": {
    "id": "uuid",
    "name": "Main Store"
  },
  "assigned_user": {
    "id": "uuid",
    "name": "Jane Smith"
  }
}
```

**Status:** Order model decoding appears correct based on current implementation.

---

### 5. DashboardStats Model - NEEDS VERIFICATION

**iOS Model Location:** `Core/Models/DashboardStats.swift`

**Backend Response (from dashboard_handlers.js):**
The dashboard endpoint returns a different structure than expected.

**Expected by iOS:**
```json
{
  "period": "this_month",
  "devices": {
    "current": { "count": 42 },
    "comparisons": [...]
  },
  "revenue": {
    "current": { "total": 8500.00 },
    "comparisons": [...]
  },
  "clients": { ... },
  "newClients": { ... },
  "returningClients": { ... }
}
```

**Actual Backend Response:**
Need to verify exact response format from `/api/dashboard/stats` endpoint. The structure may differ significantly.

---

### 6. Push Notification Preferences - CRITICAL MISMATCH

**iOS Model Location:** `Core/Networking/APIEndpoints.swift` (PushNotificationPreferences)

**Backend Response (from device_token_handlers.js:367-378):**
```json
{
  "success": true,
  "preferences": {
    "notificationsEnabled": true,
    "orderStatusChanged": true,
    "orderCreated": true,
    "orderCollected": true,
    "deviceStatusChanged": true,
    "quoteApproved": true,
    "quoteRejected": true,
    "paymentReceived": true,
    "newEnquiry": true,
    "enquiryReply": true
  }
}
```

**Issue:** iOS uses `APIResponse<PushNotificationPreferences>` but backend returns `{ success, preferences }` directly, NOT wrapped in `data` field!

**FIX REQUIRED:**
Create a dedicated response type:
```swift
struct PushPreferencesResponse: Decodable {
    let success: Bool
    let preferences: PushNotificationPreferences
}
```

And use `requestDirect` instead of `request` in the API call.

---

### 7. Enquiry Model - NEEDS VERIFICATION

**iOS Model Location:** `Core/Models/Enquiry.swift`

| iOS Field | iOS Type | Backend Field | Status |
|-----------|----------|---------------|--------|
| customerName | String | client_name | VERIFY |
| customerEmail | String | client_email | VERIFY |
| deviceType | EnquiryDeviceType | device_type (nested) | VERIFY |
| deviceBrand | String | brand | VERIFY |
| deviceModel | String | model | VERIFY |
| isRead | Bool | is_read / read status | VERIFY |

**Note:** Enquiry handling varies between customer and staff endpoints. Need to trace exact endpoints used.

---

### 8. Workflow Model - OK

**iOS Model Location:** `Core/Models/Workflow.swift`

This model uses manual `CodingKeys` to map snake_case fields, which should work correctly with the backend.

---

### 9. User Model - OK (with Int->Bool handling)

**iOS Model Location:** `Core/Models/User.swift`

The User model correctly handles SQLite integer booleans being returned as Int:
```swift
if let intValue = try? container.decode(Int.self, forKey: .isActive) {
    isActive = intValue != 0
} else {
    isActive = try container.decode(Bool.self, forKey: .isActive)
}
```

---

## SyncEngine Analysis

**File:** `Core/Storage/SyncEngine.swift`

The SyncEngine pulls data for these entities:
1. **Orders** - Uses `APIEndpoint.orders()` → Decodes as `[Order]`
2. **Devices** - Uses `APIEndpoint.devices()` → Decodes as `[Device]` **FAILS**
3. **Clients** - Uses `APIEndpoint.clients()` → Decodes as `[Client]` **FAILS**
4. **Tickets** - Uses `APIEndpoint.tickets()` → Decodes as `[Ticket]` **FAILS**

All four use `APIClient.shared.request()` which expects `APIResponse<T>` wrapper.

---

## Fix Plan

### Priority 1 - Critical (Blocking sync)

1. **Rewrite Device.swift**
   - Match backend response structure exactly
   - Add nested `DeviceTypeInfo`, `AssignedEngineer`, `SubLocation` structs
   - Change field names: `serial` → `serialNumber`, remove non-existent fields
   - Add new fields: `displayName`, `workflowType`, `colour`, `receivedAt`, `dueDate`

2. **Rewrite Client.swift**
   - Change `totalSpent` → `totalSpend`
   - Add missing fields: `countryCode`, `groups`, `deviceCount`, `averageSpend`, etc.
   - Remove fields not in response: `company`, `address`, `city`, `postcode`, `notes`, `updatedAt`

3. **Rewrite Ticket.swift**
   - Match actual backend field names
   - Remove `priority`, `orderRef`, `messageCount`
   - Update assigned user handling

### Priority 2 - High (Push Notifications)

4. **Fix Push Preferences API Call**
   - Create `PushPreferencesResponse` struct
   - Change from `request()` to `requestDirect()` since backend doesn't wrap in `data`

### Priority 3 - Medium (Dashboard)

5. **Verify DashboardStats**
   - Test `/api/dashboard/stats` endpoint manually
   - Compare response to `DashboardStats.swift` structure
   - Update model to match

### Priority 4 - Low (Cleanup)

6. **Update CoreData Entities**
   - Once Swift models are fixed, update `CDDevice`, `CDClient`, `CDTicket` attributes
   - Update CoreData model file (.xcdatamodeld)

7. **Verify Enquiry Model**
   - Test enquiry endpoints
   - Update `Enquiry.swift` if needed

---

## Testing Checklist

After fixes, verify each endpoint works:

- [ ] `GET /api/orders` - Orders list loads
- [ ] `GET /api/devices` - Devices list loads
- [ ] `GET /api/clients` - Clients list loads
- [ ] `GET /api/tickets` - Tickets list loads
- [ ] `GET /api/dashboard/stats` - Dashboard stats load
- [ ] `GET /api/user/push-preferences` - Notification settings load
- [ ] `PUT /api/user/push-preferences` - Can save notification settings
- [ ] `GET /api/enquiries` - Enquiries list loads
- [ ] Full sync completes without errors

---

## How to Debug

1. **Enable verbose logging in APIClient:**
   ```swift
   #if DEBUG
   logger.debug("Response [\(httpResponse.statusCode)]: \(String(data: data, encoding: .utf8) ?? "nil")")
   #endif
   ```

2. **Catch specific decoding errors:**
   ```swift
   } catch let DecodingError.keyNotFound(key, context) {
       logger.error("Missing key: \(key.stringValue) in \(context.debugDescription)")
   } catch let DecodingError.typeMismatch(type, context) {
       logger.error("Type mismatch: expected \(type) at \(context.codingPath)")
   }
   ```

3. **Test endpoints in terminal:**
   ```bash
   curl -H "Authorization: Bearer TOKEN" \
        "https://api.repairminder.com/api/devices?limit=1" | jq
   ```

---

## Notes for Developer

- The iOS app uses `convertFromSnakeCase` decoder strategy, so `order_id` auto-converts to `orderId`
- Backend returns nested objects (e.g., `assigned_engineer: { id, name }`) which require nested Swift structs
- Some endpoints don't wrap in `APIResponse` - use `requestDirect()` for those
- SQLite returns booleans as integers (0/1) - handle with `Int` fallback decoding
- Dates are ISO8601 format

---

**Document Created:** 2026-02-04
**Author:** Claude Code Assistant
**For:** iOS App API Verification and Bug Fixing
