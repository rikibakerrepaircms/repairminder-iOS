//
//  SettingsViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Settings View Model

/// View model for the settings screen
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published State

    /// Show logout confirmation dialog
    @Published var showLogoutConfirmation: Bool = false

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message
    @Published var errorMessage: String?

    // MARK: - Computed Properties

    /// App version string
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Build number string
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Actions

    /// Logout the current user
    func logout() async {
        isLoading = true
        defer { isLoading = false }

        // Unregister push token before logout
        await PushNotificationService.shared.unregisterToken()

        // Logout from auth manager
        await AuthManager.shared.logout()
    }
}
