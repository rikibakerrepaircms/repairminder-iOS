//
//  AppDelegate.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import UIKit
import UserNotifications
import os.log

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "AppDelegate")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        logger.debug("AppDelegate initialized with notification delegate")
        return true
    }

    // MARK: - Remote Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        logger.debug("Received device token: \(token.prefix(20))...")

        Task {
            await NotificationManager.shared.registerToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground - show banner
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        logger.debug("Foreground notification received: \(userInfo)")

        // Show banner, play sound, update badge
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap - navigate to relevant screen
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        logger.debug("Notification tapped: \(userInfo)")

        Task {
            await DeepLinkHandler.shared.handle(userInfo: userInfo)
        }

        completionHandler()
    }
}
