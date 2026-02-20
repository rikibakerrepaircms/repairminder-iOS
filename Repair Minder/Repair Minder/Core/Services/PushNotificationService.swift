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
            #if DEBUG
            print("[PushNotificationService] Authorization error: \(error)")
            #endif
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
        #if DEBUG
        print("[PushNotificationService] Device token: \(token)")
        #endif
    }

    /// Called when APNs registration fails
    func didFailToRegisterForRemoteNotifications(error: Error) {
        #if DEBUG
        print("[PushNotificationService] Failed to register: \(error)")
        #endif
    }

    /// Register the current device token with the backend
    /// - Parameter appType: "staff" or "customer"
    func registerToken(appType: String = "staff") async {
        guard let token = deviceToken else {
            #if DEBUG
            print("[PushNotificationService] No device token to register")
            #endif
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let registration = appType == "customer"
                ? DeviceTokenRegistration.forCustomer(token: token)
                : DeviceTokenRegistration.forStaff(token: token)

            if appType == "customer" {
                // Use customer auth token and customer endpoint
                try await performCustomerRequest(.customerRegisterDeviceToken, body: registration)
            } else {
                try await APIClient.shared.requestVoid(.registerDeviceToken, body: registration)
            }
            #if DEBUG
            print("[PushNotificationService] Token registered successfully (\(appType))")
            #endif
        } catch {
            #if DEBUG
            print("[PushNotificationService] Failed to register token: \(error)")
            #endif
            errorMessage = "Failed to register for notifications"
        }
    }

    /// Unregister the current device token from the backend (call on logout)
    /// - Parameter appType: "staff" or "customer" — determines which endpoint and auth to use
    func unregisterToken(appType: String = "staff") async {
        guard let token = deviceToken else {
            #if DEBUG
            print("[PushNotificationService] No device token to unregister")
            #endif
            return
        }

        do {
            let request = DeviceTokenUnregistration(deviceToken: token)
            if appType == "customer" {
                try await performCustomerRequest(.customerUnregisterDeviceToken, body: request)
            } else {
                try await APIClient.shared.requestVoid(.unregisterDeviceToken, body: request)
            }
            #if DEBUG
            print("[PushNotificationService] Token unregistered successfully (\(appType))")
            #endif
        } catch {
            // Don't surface this error to user - we're logging out anyway
            #if DEBUG
            print("[PushNotificationService] Failed to unregister token: \(error)")
            #endif
        }
    }

    // MARK: - Customer Auth Helper

    /// Perform a request using the customer auth token instead of staff auth
    private func performCustomerRequest<T: Encodable>(_ endpoint: APIEndpoint, body: T) async throws {
        guard let customerToken = CustomerAuthManager.shared.accessToken else {
            throw APIError.unauthorized
        }

        var urlRequest = URLRequest(url: URL(string: "https://api.repairminder.com\(endpoint.path)")!)
        urlRequest.httpMethod = endpoint.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(customerToken)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message
            if let json = try? JSONDecoder().decode(APIResponse<EmptyResponse>.self, from: data) {
                throw APIError.serverError(message: json.error ?? "Request failed", code: json.code)
            }
            throw APIError.serverError(message: "Request failed with status \(httpResponse.statusCode)", code: nil)
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
