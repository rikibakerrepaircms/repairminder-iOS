//
//  PushNotificationService.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import UserNotifications
import UIKit

// MARK: - Push Notification Service

/// Service for managing push notification registration and preferences
@MainActor
final class PushNotificationService: ObservableObject {

    // MARK: - Singleton

    static let shared = PushNotificationService()

    // MARK: - Published State

    /// Current push notification authorization status
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Whether push notifications are enabled at the system level
    @Published private(set) var isSystemEnabled: Bool = false

    /// The current device token (hex string)
    @Published private(set) var deviceToken: String?

    /// Loading state for API calls
    @Published var isLoading: Bool = false

    /// Error message for UI
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Initialization

    private init() {}

    // MARK: - Authorization

    /// Check current notification authorization status
    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isSystemEnabled = settings.authorizationStatus == .authorized
    }

    /// Request notification permission from the user
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await checkAuthorizationStatus()

            if granted {
                // Register for remote notifications
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

            return granted
        } catch {
            print("[PushNotificationService] Authorization error: \(error)")
            return false
        }
    }

    /// Open system settings for notifications
    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Token Management

    /// Called when APNs returns a device token
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        print("[PushNotificationService] Device token: \(token)")
    }

    /// Called when APNs registration fails
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[PushNotificationService] Failed to register: \(error)")
    }

    /// Register the current device token with the backend
    /// - Parameter appType: "staff" or "customer"
    func registerToken(appType: String = "staff") async {
        guard let token = deviceToken else {
            print("[PushNotificationService] No device token to register")
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let registration = appType == "customer"
                ? DeviceTokenRegistration.forCustomer(token: token)
                : DeviceTokenRegistration.forStaff(token: token)

            try await APIClient.shared.requestVoid(.registerDeviceToken, body: registration)
            print("[PushNotificationService] Token registered successfully")
        } catch {
            print("[PushNotificationService] Failed to register token: \(error)")
            errorMessage = "Failed to register for notifications"
        }
    }

    /// Unregister the current device token from the backend (call on logout)
    func unregisterToken() async {
        guard let token = deviceToken else {
            print("[PushNotificationService] No device token to unregister")
            return
        }

        do {
            let request = DeviceTokenUnregistration(deviceToken: token)
            try await APIClient.shared.requestVoid(.unregisterDeviceToken, body: request)
            print("[PushNotificationService] Token unregistered successfully")
        } catch {
            // Don't surface this error to user - we're logging out anyway
            print("[PushNotificationService] Failed to unregister token: \(error)")
        }
    }

    // MARK: - Preferences

    /// Fetch push notification preferences from the backend
    func fetchPreferences() async throws -> PushPreferences {
        let response: PushPreferences = try await APIClient.shared.request(.pushPreferences)
        return response
    }

    /// Update push notification preferences
    func updatePreferences(_ request: PushPreferencesUpdateRequest) async throws {
        try await APIClient.shared.requestVoid(.updatePushPreferences, body: request)
    }

    /// Update a single preference
    func updateSinglePreference(key: WritableKeyPath<PushPreferencesUpdateRequest, Bool?>, value: Bool) async throws {
        let request = PushPreferencesUpdateRequest.single(key: key, value: value)
        try await updatePreferences(request)
    }

    // MARK: - Device Tokens List

    /// Get all registered device tokens for the current user
    func fetchRegisteredTokens() async throws -> [RegisteredDeviceToken] {
        let response: [RegisteredDeviceToken] = try await APIClient.shared.request(.deviceTokens)
        return response
    }
}
