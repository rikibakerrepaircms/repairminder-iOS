//
//  NotificationManager.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import UserNotifications
import UIKit
import Combine
import os.log

/// Manages push notification registration, permissions, and token handling
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "Notifications")
    private let keychain = KeychainManager.shared

    /// The app type for push notification registration - "staff" or "customer"
    private var appType: String {
        #if CUSTOMER_APP
        return "customer"
        #else
        return "staff"
        #endif
    }

    /// Check if the user is authenticated (works for both staff and customer apps)
    private var isUserAuthenticated: Bool {
        #if CUSTOMER_APP
        // For customer app, check if we have a stored token
        return keychain.getString(for: .accessToken) != nil
        #else
        // For staff app, use AuthManager
        return AuthManager.shared.isAuthenticated
        #endif
    }

    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Public API

    /// Request permission to send notifications
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            authorizationStatus = granted ? .authorized : .denied

            if granted {
                logger.debug("Push notification permission granted")
                await registerForRemoteNotifications()
            } else {
                logger.debug("Push notification permission denied")
            }
        } catch {
            logger.error("Failed to request push permission: \(error.localizedDescription)")
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized

        // If already authorized but not registered, register now
        if isAuthorized {
            await registerForRemoteNotifications()
        }
    }

    /// Register device for remote notifications (triggers didRegisterForRemoteNotificationsWithDeviceToken)
    func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        logger.debug("Requested remote notification registration")
    }

    /// Called by AppDelegate when device token is received
    func registerToken(_ token: String) async {
        deviceToken = token
        logger.debug("Device token stored: \(token.prefix(20))...")

        // Save token locally
        try? keychain.save(token, for: .deviceToken)

        // Send token to server if authenticated
        await sendTokenToServer(token)
    }

    /// Unregister device token (call on logout)
    func unregisterToken() async {
        guard let token = deviceToken else {
            // Try to get from keychain
            if let storedToken = keychain.getString(for: .deviceToken) {
                await unregisterTokenFromServer(storedToken)
            }
            return
        }

        await unregisterTokenFromServer(token)
        deviceToken = nil
        keychain.delete(for: .deviceToken)
    }

    /// Set the app badge count
    func setBadgeCount(_ count: Int) async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(count)
            logger.debug("Badge count set to \(count)")
        } catch {
            logger.error("Failed to set badge count: \(error.localizedDescription)")
        }
    }

    /// Clear all delivered notifications
    func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        logger.debug("Cleared all delivered notifications")
    }

    // MARK: - Private

    private func sendTokenToServer(_ token: String) async {
        guard isUserAuthenticated else {
            logger.debug("Not authenticated, skipping token registration")
            return
        }

        do {
            try await APIClient.shared.requestVoid(.registerDeviceToken(token: token, appType: appType))
            logger.debug("Device token registered with server (appType: \(self.appType))")
        } catch {
            logger.error("Failed to register device token with server: \(error.localizedDescription)")
        }
    }

    private func unregisterTokenFromServer(_ token: String) async {
        do {
            try await APIClient.shared.requestVoid(.unregisterDeviceToken(token: token))
            logger.debug("Device token unregistered from server")
        } catch {
            logger.error("Failed to unregister device token: \(error.localizedDescription)")
        }
    }
}
