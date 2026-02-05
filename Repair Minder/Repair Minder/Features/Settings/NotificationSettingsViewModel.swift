//
//  NotificationSettingsViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Notification Settings View Model

/// View model for push notification preferences
@MainActor
final class NotificationSettingsViewModel: ObservableObject {

    // MARK: - Published State

    /// Current push preferences
    @Published var preferences: PushPreferences = .allEnabled

    /// Whether system notifications are enabled
    @Published var hasSystemPermission: Bool = false

    /// Loading state
    @Published var isLoading: Bool = false

    /// Whether an update is in progress
    @Published var isUpdating: Bool = false

    /// Error message
    @Published var errorMessage: String?

    /// Show error alert
    @Published var showError: Bool = false

    // MARK: - Private Properties

    private let pushService = PushNotificationService.shared

    // MARK: - Computed Properties

    /// Description of system permission status
    var systemPermissionDescription: String {
        hasSystemPermission
            ? "Notifications are enabled"
            : "Notifications are disabled in Settings"
    }

    // MARK: - Load Data

    /// Load notification settings
    func load() async {
        isLoading = true
        defer { isLoading = false }

        // Check system permission
        await pushService.checkAuthorizationStatus()
        hasSystemPermission = pushService.isSystemEnabled

        // Fetch preferences from backend
        do {
            preferences = try await pushService.fetchPreferences()
        } catch {
            print("[NotificationSettingsViewModel] Failed to fetch preferences: \(error)")
            // Use defaults on error
            preferences = .allEnabled
        }
    }

    // MARK: - Update Preferences

    /// Update master toggle - when disabled, turns off all preferences
    func updateMasterToggle(_ enabled: Bool) async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            if enabled {
                // Just enable master toggle
                let request = PushPreferencesUpdateRequest(notificationsEnabled: true)
                try await pushService.updatePreferences(request)
            } else {
                // Disable everything
                try await pushService.updatePreferences(.disableAll)
                // Update local state
                preferences = .allDisabled
            }
        } catch {
            handleError(error)
            // Revert local state
            preferences.notificationsEnabled = !enabled
        }
    }

    /// Update a single preference
    func updateSinglePreference(key: WritableKeyPath<PushPreferencesUpdateRequest, Bool?>, value: Bool) async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            try await pushService.updateSinglePreference(key: key, value: value)
        } catch {
            handleError(error)
            // Revert would need to track which key changed - for simplicity, reload
            await load()
        }
    }

    // MARK: - System Settings

    /// Open system settings for notifications
    func openSystemSettings() {
        pushService.openSystemSettings()
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let apiError = error as? APIError {
            errorMessage = apiError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
}
