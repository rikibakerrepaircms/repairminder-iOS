# Stage 11: Push Notifications

## Objective

Implement Apple Push Notification Service (APNS) for real-time alerts on order updates, assignments, messages, **new enquiries**, and **ticket reopening**.

---

## Dependencies

**Requires:** [See: Stage 05] complete - Sync engine for data refresh on notification
**Requires:** Apple Developer Account with push notification capability

---

## Complexity

**Medium** - APNS setup, token management, deep linking

---

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder.entitlements` | Add push notification entitlement |
| `Info.plist` | Add background modes |
| `Repair_MinderApp.swift` | Add AppDelegate for push handling |

---

## Files to Create

| File | Purpose |
|------|---------|
| `App/AppDelegate.swift` | Push notification delegate |
| `Core/Notifications/NotificationManager.swift` | Push registration & handling |
| `Core/Notifications/NotificationPayload.swift` | Payload parsing |
| `Core/Notifications/DeepLinkHandler.swift` | Handle notification taps |

---

## Implementation Details

### 1. App Delegate

```swift
// App/AppDelegate.swift
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            await NotificationManager.shared.registerToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task {
            await DeepLinkHandler.shared.handle(userInfo: userInfo)
        }
        completionHandler()
    }
}
```

### 2. Update App Entry Point

```swift
// Repair_MinderApp.swift (add delegate)
@main
struct Repair_MinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(router)
                .task {
                    await appState.checkAuthStatus()
                    await NotificationManager.shared.requestPermission()
                }
        }
    }
}
```

### 3. Notification Manager

```swift
// Core/Notifications/NotificationManager.swift
import UserNotifications
import os.log

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var deviceToken: String?

    private let logger = Logger(subsystem: "com.mendmyi.repairminder", category: "Notifications")

    private init() {}

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

            logger.debug("Push notification permission: \(granted)")
        } catch {
            logger.error("Failed to request push permission: \(error)")
        }
    }

    func registerToken(_ token: String) async {
        deviceToken = token
        logger.debug("Device token: \(token.prefix(20))...")

        // Send token to server
        guard AuthManager.shared.isAuthenticated else { return }

        struct TokenPayload: Encodable {
            let deviceToken: String
            let platform: String = "ios"
        }

        do {
            try await APIClient.shared.requestVoid(
                APIEndpoint(
                    path: "/api/user/device-token",
                    method: .post,
                    body: TokenPayload(deviceToken: token)
                )
            )
            logger.debug("Device token registered with server")
        } catch {
            logger.error("Failed to register device token: \(error)")
        }
    }

    func unregisterToken() async {
        guard let token = deviceToken else { return }

        struct TokenPayload: Encodable {
            let deviceToken: String
        }

        try? await APIClient.shared.requestVoid(
            APIEndpoint(
                path: "/api/user/device-token",
                method: .delete,
                body: TokenPayload(deviceToken: token)
            )
        )

        deviceToken = nil
    }

    func setBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}
```

### 4. Notification Payload

```swift
// Core/Notifications/NotificationPayload.swift
import Foundation

struct NotificationPayload {
    let type: NotificationType
    let entityId: String?
    let title: String
    let body: String

    enum NotificationType: String {
        case orderCreated = "order_created"
        case orderStatusChanged = "order_status_changed"
        case deviceAssigned = "device_assigned"
        case deviceStatusChanged = "device_status_changed"
        case ticketMessage = "ticket_message"
        case ticketReopened = "ticket_reopened"       // Ticket reopened by customer
        case paymentReceived = "payment_received"
        case enquiryReceived = "enquiry_received"     // New enquiry from customer
        case enquiryReply = "enquiry_reply"           // Customer replied to enquiry
        case quoteApproved = "quote_approved"         // Customer approved quote
        case quoteRejected = "quote_rejected"         // Customer rejected quote
        case unknown
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any] else {
            return nil
        }

        title = alert["title"] as? String ?? ""
        body = alert["body"] as? String ?? ""

        let typeString = userInfo["type"] as? String ?? ""
        type = NotificationType(rawValue: typeString) ?? .unknown

        entityId = userInfo["entity_id"] as? String
    }
}
```

### 5. Deep Link Handler

```swift
// Core/Notifications/DeepLinkHandler.swift
import Foundation

@MainActor
final class DeepLinkHandler {
    static let shared = DeepLinkHandler()

    private init() {}

    func handle(userInfo: [AnyHashable: Any]) async {
        guard let payload = NotificationPayload(userInfo: userInfo) else { return }

        // Trigger data refresh
        await SyncEngine.shared.performFullSync()

        // Navigate based on notification type
        guard let entityId = payload.entityId else { return }

        let router = AppRouter.shared // Would need singleton or environment access

        switch payload.type {
        case .orderCreated, .orderStatusChanged:
            router.navigate(to: .orderDetail(id: entityId))

        case .deviceAssigned, .deviceStatusChanged:
            router.navigate(to: .deviceDetail(id: entityId))

        case .ticketMessage, .ticketReopened:
            router.navigate(to: .ticketDetail(id: entityId))

        case .paymentReceived, .quoteApproved, .quoteRejected:
            router.navigate(to: .orderDetail(id: entityId))

        case .enquiryReceived, .enquiryReply:
            router.navigate(to: .enquiryDetail(id: entityId))

        case .unknown:
            break
        }
    }

    func handle(url: URL) {
        // Handle URL scheme deep links
        // repairminder://order/123
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else { return }

        let pathComponents = components.path.split(separator: "/").map(String.init)

        switch host {
        case "order":
            if let id = pathComponents.first {
                // Navigate to order
            }
        case "device":
            if let id = pathComponents.first {
                // Navigate to device
            }
        default:
            break
        }
    }
}
```

---

## Entitlements

```xml
<!-- Repair Minder.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
```

---

## Server Requirements

The backend needs to:
1. Accept device token registration: `POST /api/user/device-token`
2. Store tokens per user/device
3. Send push notifications via APNS when events occur
4. Include `type` and `entity_id` in notification payload

### Example Payloads from Server

**Order Status Changed:**
```json
{
  "aps": {
    "alert": {
      "title": "Order Ready",
      "body": "Order #1234 is ready for collection"
    },
    "badge": 1,
    "sound": "default"
  },
  "type": "order_status_changed",
  "entity_id": "order-uuid-here"
}
```

**New Enquiry (Staff):**
```json
{
  "aps": {
    "alert": {
      "title": "New Enquiry",
      "body": "John Smith has a question about iPhone 15 repair"
    },
    "badge": 3,
    "sound": "default"
  },
  "type": "enquiry_received",
  "entity_id": "enquiry-uuid-here"
}
```

**Ticket Reopened (Staff):**
```json
{
  "aps": {
    "alert": {
      "title": "Ticket Reopened",
      "body": "Customer replied to ticket #4521"
    },
    "badge": 2,
    "sound": "default"
  },
  "type": "ticket_reopened",
  "entity_id": "ticket-uuid-here"
}
```

**Quote Approved (Staff):**
```json
{
  "aps": {
    "alert": {
      "title": "Quote Approved!",
      "body": "John Smith approved quote for Order #1234 (£189.00)"
    },
    "badge": 1,
    "sound": "default"
  },
  "type": "quote_approved",
  "entity_id": "order-uuid-here"
}
```

**Quote Rejected (Staff):**
```json
{
  "aps": {
    "alert": {
      "title": "Quote Declined",
      "body": "John Smith declined quote for Order #1234"
    },
    "badge": 1,
    "sound": "default"
  },
  "type": "quote_rejected",
  "entity_id": "order-uuid-here"
}
```

---

## Test Cases

| Test | Expected |
|------|----------|
| Permission prompt | Shows on first launch |
| Token registered | Sent to server after login |
| Foreground notification | Banner shown |
| Background tap | Opens relevant screen |
| Deep link URL | Navigates correctly |
| Logout | Token unregistered |
| **New enquiry notification** | **Opens enquiry detail** |
| **Enquiry reply notification** | **Opens enquiry with new message** |
| **Ticket reopened notification** | **Opens ticket detail** |
| **Quote approved notification** | **Opens order detail** |
| **Quote rejected notification** | **Opens order detail** |

---

## Acceptance Checklist

- [ ] Push permission requested on launch
- [ ] Device token captured and sent to server
- [ ] Foreground notifications display as banner
- [ ] Tapping notification navigates to correct screen
- [ ] Badge count updates
- [ ] Token unregistered on logout
- [ ] Deep link URL scheme works
- [ ] Works in both debug and release builds
- [ ] **New enquiry notifications work**
- [ ] **Enquiry reply notifications navigate correctly**
- [ ] **Ticket reopened notifications work**
- [ ] **Quote approved/rejected notifications work**

---

## Handoff Notes

**For Stage 12:**
- Same notification system can work for customer portal
- Different notification types for customers (order ready, quote ready, etc.)

**For Stage 13:**
- Add notification preferences in Settings
- Allow disabling specific notification types

**For Stage 15:**
- Enquiry notifications drive engagement
- Badge count should include unread enquiries
- Consider grouping enquiry notifications
