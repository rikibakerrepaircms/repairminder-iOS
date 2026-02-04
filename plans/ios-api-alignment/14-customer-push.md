# Stage 14: Customer Push Notifications

## Objective

Implement push notification registration and handling for the customer app.

## Dependencies

- **Requires**: Stage 10 complete (Staff push as reference)
- **Requires**: Stage 11 complete (Customer auth working)

## Complexity

**Medium** - Similar to staff push but with customer-specific handling

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Customer/CustomerApp.swift` | Wire up AppDelegate |
| `Repair Minder/Customer/CustomerAppDelegate.swift` | If exists, add push handling |

## Files to Create

| File | Purpose |
|------|---------|
| `Repair Minder/Customer/Core/CustomerPushService.swift` | Customer push registration |
| `Repair Minder/Customer/CustomerAppDelegate.swift` | If doesn't exist |

## Backend Reference

### Endpoints

Same endpoints as staff, with different `appType`:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `POST /api/user/device-token` | POST | Register token with `appType: "customer"` |
| `DELETE /api/user/device-token` | DELETE | Unregister on logout |

### Push Payload for Customers

```json
{
  "aps": {
    "alert": {
      "title": "Order Update",
      "body": "Your repair is ready for collection!"
    },
    "badge": 1,
    "sound": "default"
  },
  "type": "order_status",
  "order_id": "uuid"
}
```

### Customer Push Types

- `order_status` - Order status changed
- `quote_ready` - Quote ready for approval
- `repair_complete` - Repair finished
- `message` - New message from shop

## Implementation Details

### 1. CustomerPushService

```swift
// Repair Minder/Customer/Core/CustomerPushService.swift

import Foundation
import UIKit
import UserNotifications
import os.log

@MainActor
class CustomerPushService: NSObject, ObservableObject {
    static let shared = CustomerPushService()

    @Published private(set) var isRegistered = false
    @Published private(set) var deviceToken: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder-Customer", category: "Push")

    private override init() {
        super.init()
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                logger.debug("Push permission granted")
            }
            return granted
        } catch {
            logger.error("Push permission error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Token Handling

    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        logger.debug("Customer device token: \(tokenString)")

        Task {
            await registerTokenWithBackend(tokenString)
        }
    }

    func handleRegistrationError(_ error: Error) {
        logger.error("Push registration failed: \(error.localizedDescription)")
    }

    // MARK: - Backend Registration

    private func registerTokenWithBackend(_ token: String) async {
        // Only register if customer is authenticated
        guard CustomerAuthManager.shared.isAuthenticated else {
            logger.debug("Skipping token registration - not authenticated")
            return
        }

        do {
            try await APIClient.shared.requestVoid(
                .registerDeviceToken(token: token, appType: "customer")  // Note: "customer" not "staff"
            )
            isRegistered = true
            logger.debug("Customer token registered with backend")
        } catch {
            logger.error("Failed to register customer token: \(error.localizedDescription)")
        }
    }

    func unregisterToken() async {
        guard let token = deviceToken else { return }

        do {
            try await APIClient.shared.requestVoid(
                .unregisterDeviceToken(token: token)
            )
            isRegistered = false
            logger.debug("Customer token unregistered")
        } catch {
            logger.error("Failed to unregister token: \(error.localizedDescription)")
        }
    }
}
```

### 2. CustomerAppDelegate

```swift
// Repair Minder/Customer/CustomerAppDelegate.swift

import UIKit
import UserNotifications

class CustomerAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Push Token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            CustomerPushService.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            CustomerPushService.shared.handleRegistrationError(error)
        }
    }

    // MARK: - Notification Presentation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner even when app is in foreground
        return [.banner, .badge, .sound]
    }

    // MARK: - Notification Tap

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await handleNotificationTap(userInfo: userInfo)
    }

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "order_status", "quote_ready", "repair_complete":
            if let orderId = userInfo["order_id"] as? String {
                // Navigate to order detail
                NotificationCenter.default.post(
                    name: .customerPushNavigateToOrder,
                    object: nil,
                    userInfo: ["orderId": orderId]
                )
            }

        case "message":
            if let orderId = userInfo["order_id"] as? String {
                // Navigate to order detail (messages section)
                NotificationCenter.default.post(
                    name: .customerPushNavigateToOrder,
                    object: nil,
                    userInfo: ["orderId": orderId, "section": "messages"]
                )
            }

        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let customerPushNavigateToOrder = Notification.Name("customerPushNavigateToOrder")
}
```

### 3. Wire Up in CustomerApp

```swift
// In CustomerApp.swift

@main
struct CustomerApp: App {
    @UIApplicationDelegateAdaptor(CustomerAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            CustomerRootView()
                .onReceive(NotificationCenter.default.publisher(for: .customerPushNavigateToOrder)) { notification in
                    // Handle deep link navigation
                    if let orderId = notification.userInfo?["orderId"] as? String {
                        // Navigate to order
                    }
                }
        }
    }
}
```

### 4. Request Permission on Login

```swift
// In CustomerLoginViewModel after successful login:

func onLoginSuccess() async {
    // Request push permission
    let granted = await CustomerPushService.shared.requestPermission()
    if granted {
        // Token will be registered automatically when received
    }
}
```

### 5. Unregister on Logout

```swift
// In CustomerAuthManager.logout():

func logout() async {
    // Unregister push token first
    await CustomerPushService.shared.unregisterToken()

    // Then clear auth state
    // ...
}
```

## Database Changes

None

## Test Cases

| Test | Expected |
|------|----------|
| Login prompts for permission | Permission dialog shown |
| Permission granted | Token registered with `appType: customer` |
| Receive order status push | Notification displayed |
| Tap notification | Navigates to order detail |
| Quote ready push | Notification shown |
| Logout | Token unregistered |
| Login again | Token re-registered |

## Acceptance Checklist

- [ ] CustomerPushService created
- [ ] CustomerAppDelegate handles push
- [ ] Token registered with `appType: "customer"`
- [ ] Token unregistered on logout
- [ ] Foreground notifications display
- [ ] Notification tap navigates to order
- [ ] Deep linking works for order notifications
- [ ] Badge count handled

## Deployment

1. Ensure separate push certificate/key for customer app
2. Build and run on physical device
3. Login as customer
4. Accept notification permission
5. Verify token registered (check backend logs)
6. Send test notification from backend
7. Verify notification received and tap navigates correctly

## Handoff Notes

- Customer app uses `appType: "customer"` vs staff's `appType: "staff"`
- Push certificates may need separate configuration for customer app
- Deep linking uses `Notification.Name` for navigation
- Consider badge count management
