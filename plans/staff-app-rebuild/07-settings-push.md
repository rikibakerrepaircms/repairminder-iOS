# Stage 07: Settings & Push Notifications

## Objective

Implement settings screen and push notification registration/preferences for staff users.

---

## ⚠️ Pre-Implementation Verification

**Before writing any code, verify the following against the backend source files:**

1. **Device token endpoints** - Read `/Volumes/Riki Repos/repairminder/worker/device_token_handlers.js` and verify:
   - Register token request/response shape
   - Required fields (deviceToken, platform, appType)
   - Optional metadata fields

2. **Push preferences** - Verify preference field names match the backend:
   - All toggle keys (orderStatusChanged, deviceStatusChanged, etc.)
   - Master toggle field name (notificationsEnabled)

3. **Push triggers** - Read `/Volumes/Riki Repos/repairminder/worker/src/order-push-triggers.js` to understand:
   - What events trigger notifications
   - Payload structure for deep linking

```bash
# Quick verification commands
grep -n "registerDeviceToken\|getPreferences" /Volumes/Riki\ Repos/repairminder/worker/device_token_handlers.js
grep -n "triggerOrderStatusPush\|triggerDeviceStatusPush" /Volumes/Riki\ Repos/repairminder/worker/src/order-push-triggers.js
```

**Do not proceed until you've verified the response shapes match this documentation.**

---

## Backend Implementation Status ✅

> **The backend push notification system is fully implemented and production-ready.**

### D1 Tables (Migrations 0265, 0266)

| Table | Purpose |
|-------|---------|
| `device_tokens` | Stores APNS tokens with `user_id`, `company_id`, `platform`, `app_type`, `device_name`, `is_active` |
| `push_notification_preferences` | Per-user toggles for each notification type |
| `push_notification_log` | Audit trail with delivery status, `apns_id`, error tracking |

### Backend Files

| File | Purpose |
|------|---------|
| `device_token_handlers.js` | API endpoint handlers |
| `src/apns.js` | APNs JWT auth + HTTP/2 sending |
| `src/order-push-triggers.js` | 8 trigger functions called from order handlers |

### Trigger Functions (All Implemented)

- `triggerOrderStatusPush` - Staff notified of order status changes
- `triggerCustomerOrderStatusPush` - Customer app order updates
- `triggerDeviceStatusPush` - Device status changes (prioritizes assigned engineer)
- `triggerNewEnquiryPush` - New customer enquiry
- `triggerEnquiryReplyPush` - Customer reply on ticket
- `triggerQuoteApprovedPush` - Quote approved by customer
- `triggerQuoteRejectedPush` - Quote rejected
- `triggerPaymentReceivedPush` - Payment received

---

## API Endpoints

### POST /api/user/device-token

Register device token for push notifications.

**Request:**
```json
{
  "deviceToken": "apns_token_string",
  "platform": "ios",
  "appType": "staff",
  "deviceName": "iPhone 15 Pro",
  "osVersion": "17.4",
  "appVersion": "1.0.0"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Device token registered successfully"
}
```

**Notes:**
- `platform`: Must be `"ios"` or `"android"`
- `appType`: Must be `"staff"` or `"customer"` - determines which notifications are sent
- `deviceName`, `osVersion`, `appVersion` are optional but recommended
- Uses upsert - updates existing token if already registered

---

### DELETE /api/user/device-token

Unregister device token on logout.

**Request:**
```json
{
  "deviceToken": "apns_token_string"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Device token unregistered successfully"
}
```

**Notes:**
- Marks token as inactive (soft delete for audit trail)
- Call this on logout to stop receiving notifications

---

### GET /api/user/device-tokens

List user's registered device tokens.

**Response:**
```json
{
  "success": true,
  "tokens": [
    {
      "id": "uuid",
      "platform": "ios",
      "app_type": "staff",
      "device_name": "iPhone 15 Pro",
      "os_version": "17.4",
      "app_version": "1.0.0",
      "last_used_at": "2024-01-15T10:30:00Z",
      "created_at": "2024-01-01T09:00:00Z"
    }
  ]
}
```

---

### GET /api/user/push-preferences

Get push notification preferences.

**Response:**
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

**Notes:**
- Returns defaults (all enabled) if no preferences saved
- `notificationsEnabled` is the master toggle

---

### PUT /api/user/push-preferences

Update push notification preferences.

**Request (partial update supported):**
```json
{
  "notificationsEnabled": true,
  "orderStatusChanged": false,
  "newEnquiry": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "Push preferences updated successfully"
}
```

**Notes:**
- Only send fields you want to update
- Creates preferences record if none exists

---

## Push Notification Payload Structure

Push notifications include custom data for deep linking:

```json
{
  "aps": {
    "alert": {
      "title": "Order #1234 Updated",
      "body": "Status changed to Ready for Collection"
    },
    "sound": "default",
    "badge": 1
  },
  "type": "order_status_changed",
  "entity_type": "order",
  "entity_id": "order-uuid"
}
```

### Notification Types

| Type | Entity Type | Description |
|------|-------------|-------------|
| `order_created` | `order` | New order created |
| `order_status_changed` | `order` | Order status updated |
| `device_assigned` | `device` | Device assigned to technician |
| `device_status_changed` | `device` | Device status updated |
| `quote_approved` | `order` | Customer approved quote |
| `quote_rejected` | `order` | Customer rejected quote |
| `payment_received` | `order` | Payment received |
| `enquiry_received` | `enquiry` | New enquiry from customer |
| `enquiry_reply` | `enquiry` | Reply to enquiry |
| `ticket_message` | `ticket` | New support ticket message |

---

## Swift Models

### DeviceTokenRegistration.swift

```swift
struct DeviceTokenRegistration: Codable {
    let deviceToken: String
    let platform: String
    let appType: String
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?

    static func forStaff(
        token: String,
        deviceName: String? = nil,
        osVersion: String? = nil,
        appVersion: String? = nil
    ) -> DeviceTokenRegistration {
        DeviceTokenRegistration(
            deviceToken: token,
            platform: "ios",
            appType: "staff",
            deviceName: deviceName,
            osVersion: osVersion,
            appVersion: appVersion
        )
    }
}
```

### PushPreferences.swift

```swift
struct PushPreferences: Codable {
    var notificationsEnabled: Bool
    var orderStatusChanged: Bool
    var orderCreated: Bool
    var orderCollected: Bool
    var deviceStatusChanged: Bool
    var quoteApproved: Bool
    var quoteRejected: Bool
    var paymentReceived: Bool
    var newEnquiry: Bool
    var enquiryReply: Bool

    static let allEnabled = PushPreferences(
        notificationsEnabled: true,
        orderStatusChanged: true,
        orderCreated: true,
        orderCollected: true,
        deviceStatusChanged: true,
        quoteApproved: true,
        quoteRejected: true,
        paymentReceived: true,
        newEnquiry: true,
        enquiryReply: true
    )
}

struct PushPreferencesResponse: Codable {
    let success: Bool
    let preferences: PushPreferences
}
```

### NotificationPayload.swift

```swift
enum NotificationType: String, Codable {
    case orderCreated = "order_created"
    case orderStatusChanged = "order_status_changed"
    case deviceAssigned = "device_assigned"
    case deviceStatusChanged = "device_status_changed"
    case quoteApproved = "quote_approved"
    case quoteRejected = "quote_rejected"
    case paymentReceived = "payment_received"
    case enquiryReceived = "enquiry_received"
    case enquiryReply = "enquiry_reply"
    case ticketMessage = "ticket_message"
}

struct NotificationPayload {
    let type: NotificationType?
    let entityType: String?
    let entityId: String?

    init(userInfo: [AnyHashable: Any]) {
        self.type = (userInfo["type"] as? String).flatMap(NotificationType.init)
        self.entityType = userInfo["entity_type"] as? String
        self.entityId = userInfo["entity_id"] as? String
    }
}
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/PushPreferences.swift` | Preferences model |
| `Core/Models/DeviceTokenRegistration.swift` | Token registration model |
| `Core/Models/NotificationPayload.swift` | Push payload parsing |
| `Core/Services/PushNotificationService.swift` | API calls for tokens/preferences |
| `Core/Services/DeepLinkHandler.swift` | Parse notification and navigate |
| `Features/Settings/SettingsView.swift` | Settings screen UI |
| `Features/Settings/SettingsViewModel.swift` | Settings logic |
| `Features/Settings/NotificationSettingsView.swift` | Push preferences toggles |
| `Features/Settings/NotificationSettingsViewModel.swift` | Preferences API calls |

---

## AppDelegate Integration

Push notifications require AppDelegate methods:

```swift
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    Task {
        await PushNotificationService.shared.registerToken(token)
    }
}

func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
) {
    print("Failed to register for push: \(error)")
}
```

---

## Token Lifecycle

1. **On Login**: Request push permission, register token with `appType: "staff"`
2. **On App Launch**: Re-register token (handles token refresh)
3. **On Logout**: Unregister token via DELETE endpoint
4. **On Token Refresh**: System calls `didRegisterForRemoteNotificationsWithDeviceToken` - re-register

---

## Deep Link Handling

Parse notification payload and navigate:

```swift
class DeepLinkHandler {
    func handle(payload: NotificationPayload) {
        guard let type = payload.type, let entityId = payload.entityId else { return }

        switch type {
        case .orderCreated, .orderStatusChanged, .quoteApproved, .quoteRejected, .paymentReceived:
            // Navigate to order detail
            NavigationManager.shared.navigateToOrder(id: entityId)

        case .deviceAssigned, .deviceStatusChanged:
            // Navigate to device detail
            NavigationManager.shared.navigateToDevice(id: entityId)

        case .enquiryReceived, .enquiryReply:
            // Navigate to enquiry detail
            NavigationManager.shared.navigateToEnquiry(id: entityId)

        case .ticketMessage:
            // Navigate to ticket/support
            NavigationManager.shared.navigateToTicket(id: entityId)
        }
    }
}
```

---

## Settings Screen Layout

```
Settings
├── Account
│   ├── Profile (name, email)
│   └── Change Password
├── Notifications
│   └── Push Notification Settings →
├── About
│   ├── App Version
│   └── Terms & Privacy
└── Sign Out
```

### Notification Settings Screen

```
Push Notifications
├── Enable Notifications (master toggle)
├── Orders
│   ├── Order Created
│   ├── Status Changed
│   └── Order Collected
├── Quotes & Payments
│   ├── Quote Approved
│   ├── Quote Rejected
│   └── Payment Received
├── Devices
│   └── Device Status Changed
└── Enquiries
    ├── New Enquiry
    └── Enquiry Reply
```

---

## Verification

### Test Token Registration

```bash
# Register token
curl -X POST https://api.repairminder.mendmyi.com/api/user/device-token \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceToken": "test_apns_token",
    "platform": "ios",
    "appType": "staff",
    "deviceName": "iPhone 15 Pro",
    "osVersion": "17.4",
    "appVersion": "1.0.0"
  }'

# Get preferences
curl https://api.repairminder.mendmyi.com/api/user/push-preferences \
  -H "Authorization: Bearer {token}" | jq .

# Update preferences
curl -X PUT https://api.repairminder.mendmyi.com/api/user/push-preferences \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"newEnquiry": false}'
```

### Verify in D1 Database

```bash
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT device_token, platform, app_type, device_name FROM device_tokens WHERE is_active = 1 LIMIT 5"
```

---

## Acceptance Criteria

- [ ] Token registers on login with correct `appType: "staff"`
- [ ] Token unregisters on logout
- [ ] Push preferences load correctly
- [ ] Individual preferences can be toggled
- [ ] Master toggle disables all notifications
- [ ] Push notifications received when app backgrounded
- [ ] Tapping notification navigates to correct screen
- [ ] No decode errors in API responses
