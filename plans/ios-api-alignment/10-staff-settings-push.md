# Stage 10: Staff Settings & Push Notifications

## Objective

Fix settings view and implement push notification registration for the staff app.

## Dependencies

- **Requires**: Stage 04 complete (API client working)
- **Requires**: Apple Push Notification certificates configured

## Complexity

**High** - Push notification implementation is new functionality

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Features/Settings/SettingsViewModel.swift` | Fix settings API |
| `Repair Minder/Features/Settings/SettingsView.swift` | Update bindings |
| `Repair Minder/Features/Settings/NotificationSettingsView.swift` | Fix preferences API |
| `Repair Minder/App/AppDelegate.swift` | Add push registration |
| `Repair Minder/Repair_MinderApp.swift` | Wire up AppDelegate |

## Files to Create

| File | Purpose |
|------|---------|
| `Repair Minder/Core/Notifications/PushNotificationService.swift` | Handle push registration |

## Backend Reference

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /api/user/settings` | GET | Get user settings |
| `PATCH /api/user/settings` | PATCH | Update user settings |
| `POST /api/user/device-token` | POST | Register push token |
| `DELETE /api/user/device-token` | DELETE | Unregister token |
| `GET /api/user/push-preferences` | GET | Get notification preferences |
| `PUT /api/user/push-preferences` | PUT | Update preferences |

### Critical: Push Preferences Response Format

The push preferences endpoint returns:
```json
{
  "success": true,
  "preferences": {
    "notificationsEnabled": true,
    "orderStatusChanged": true,
    ...
  }
}
```

**NOT** wrapped in `data` field! Requires custom response type.

## Implementation Details

### 1. PushNotificationService

```swift
// Repair Minder/Core/Notifications/PushNotificationService.swift

import Foundation
import UIKit
import os.log

@MainActor
class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published private(set) var isRegistered = false
    @Published private(set) var deviceToken: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "Push")

    private override init() {
        super.init()
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            logger.error("Push permission error: \(error.localizedDescription)")
            return false
        }
    }

    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        logger.debug("Device token: \(tokenString)")

        // Register with backend
        Task {
            await registerTokenWithBackend(tokenString)
        }
    }

    func handleRegistrationError(_ error: Error) {
        logger.error("Push registration failed: \(error.localizedDescription)")
    }

    private func registerTokenWithBackend(_ token: String) async {
        do {
            try await APIClient.shared.requestVoid(
                .registerDeviceToken(token: token, appType: "staff")
            )
            isRegistered = true
            logger.debug("Token registered with backend")
        } catch {
            logger.error("Failed to register token: \(error.localizedDescription)")
        }
    }

    func unregisterToken() async {
        guard let token = deviceToken else { return }

        do {
            try await APIClient.shared.requestVoid(
                .unregisterDeviceToken(token: token)
            )
            isRegistered = false
            logger.debug("Token unregistered")
        } catch {
            logger.error("Failed to unregister token: \(error.localizedDescription)")
        }
    }
}
```

### 2. AppDelegate Updates

```swift
// In AppDelegate.swift

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationService.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationService.shared.handleRegistrationError(error)
        }
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        // Handle deep linking based on notification payload
        await handleNotificationTap(userInfo: userInfo)
    }

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        // Extract type and ID from payload
        if let type = userInfo["type"] as? String,
           let id = userInfo["id"] as? String {
            // Post notification for deep link handling
            NotificationCenter.default.post(
                name: .pushNotificationTapped,
                object: nil,
                userInfo: ["type": type, "id": id]
            )
        }
    }
}

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}
```

### 3. Fix Push Preferences Response

Create custom response type since it doesn't use `data` wrapper:

```swift
// In APIEndpoints.swift or separate file

struct PushPreferencesResponse: Decodable {
    let success: Bool
    let preferences: PushNotificationPreferences
}
```

### 4. NotificationSettingsView Updates

```swift
@MainActor
@Observable
final class NotificationSettingsViewModel {
    private(set) var preferences: PushNotificationPreferences?
    private(set) var isLoading = false
    var error: String?

    func loadPreferences() async {
        isLoading = true

        do {
            // Use requestDirect since response doesn't wrap in 'data'
            let response: PushPreferencesResponse = try await APIClient.shared.requestDirect(
                .getPushPreferences(),
                responseType: PushPreferencesResponse.self
            )
            preferences = response.preferences
        } catch {
            self.error = "Failed to load notification settings"
        }

        isLoading = false
    }

    func updatePreferences(_ newPrefs: PushNotificationPreferences) async {
        do {
            try await APIClient.shared.requestVoid(
                .updatePushPreferences(preferences: newPrefs)
            )
            preferences = newPrefs
        } catch {
            self.error = "Failed to save settings"
        }
    }
}
```

### 5. Add requestDirect to APIClient

If not already present, add method for non-wrapped responses:

```swift
// In APIClient.swift

func requestDirect<T: Decodable>(
    _ endpoint: APIEndpoint,
    responseType: T.Type
) async throws -> T {
    let (data, response) = try await performRequest(endpoint)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        throw APIError.httpError(httpResponse.statusCode)
    }

    return try decoder.decode(T.self, from: data)
}
```

### 6. Register on Login, Unregister on Logout

In login flow:
```swift
// After successful login
await PushNotificationService.shared.requestPermission()
```

In logout flow:
```swift
// Before clearing auth
await PushNotificationService.shared.unregisterToken()
```

## Database Changes

None

## Test Cases

| Test | Expected |
|------|----------|
| App launch requests permission | Permission dialog shown |
| Permission granted | Token registered with backend |
| Settings load | Preferences displayed |
| Toggle preference | Saved to backend |
| Receive push (foreground) | Banner displayed |
| Receive push (background) | Notification in tray |
| Tap notification | Deep links to correct screen |
| Logout | Token unregistered |

## Acceptance Checklist

- [ ] PushNotificationService created
- [ ] AppDelegate handles push registration
- [ ] Device token sent to backend on registration
- [ ] Push preferences load without decode error
- [ ] Push preferences save successfully
- [ ] Notification permission requested on login
- [ ] Token unregistered on logout
- [ ] Foreground notifications display
- [ ] Notification tap triggers deep link

## Deployment

1. Ensure push notification capability added in Xcode
2. Ensure APN certificates configured
3. Build and run on device (push doesn't work in simulator)
4. Accept notification permission
5. Verify token appears in Xcode console
6. Check backend received token
7. Test notification from backend/admin

## Handoff Notes

- Push requires physical device for testing
- Push preferences response doesn't use `data` wrapper
- Deep linking needs integration with app navigation
- Consider adding badge count management
