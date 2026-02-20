//
//  MacAppDelegate.swift
//  Repair Minder
//

#if os(macOS)
import AppKit
import UserNotifications

class MacAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Remote Notifications

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        #if DEBUG
        print("[MacAppDelegate] Got APNs token: \(tokenString.prefix(20))...")
        #endif

        Task { @MainActor in
            PushNotificationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)

            // Auto-register token if user is authenticated
            if AuthManager.shared.authState == .authenticated {
                #if DEBUG
                print("[MacAppDelegate] User authenticated, registering token with backend...")
                #endif
                await PushNotificationService.shared.registerToken(appType: "staff")
            } else if CustomerAuthManager.shared.authState == .authenticated {
                #if DEBUG
                print("[MacAppDelegate] Customer authenticated, registering token with backend...")
                #endif
                await PushNotificationService.shared.registerToken(appType: "customer")
            } else {
                #if DEBUG
                print("[MacAppDelegate] User not authenticated, skipping token registration")
                #endif
            }
        }
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("[MacAppDelegate] Failed to register for push notifications: \(error.localizedDescription)")
        #endif
        Task { @MainActor in
            PushNotificationService.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Task { @MainActor in
            if DeepLinkHandler.shared.shouldDisplayNotificationInForeground(userInfo: userInfo) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([])
            }
        }
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            DeepLinkHandler.shared.handleNotification(userInfo: userInfo)
        }
        completionHandler()
    }
}
#endif
