//
//  AppState.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI

/// Global application state managing which portal the user is in and overall auth status
@MainActor
final class AppState: ObservableObject {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Dependencies

    private let authManager = AuthManager.shared
    private let customerAuthManager = CustomerAuthManager.shared

    // MARK: - Published State

    /// The current view state of the app
    @Published private(set) var currentState: AppViewState = .loading

    /// The selected user role (Staff or Customer)
    @Published var selectedRole: AppUserRole? {
        didSet {
            if let role = selectedRole {
                AppUserRole.save(role)
            }
        }
    }

    // MARK: - App View State

    enum AppViewState: Equatable {
        /// App is loading (checking for existing session)
        case loading
        /// User needs to select role (Staff/Customer)
        case roleSelection
        /// Staff user needs to log in
        case staffLogin
        /// Customer user needs to log in
        case customerLogin
        /// User needs to set up a passcode (first login)
        case passcodeSetup
        /// Staff user is authenticated - show staff dashboard
        case staffDashboard
        /// Customer user is authenticated - show customer portal
        case customerPortal
        /// User's company is in quarantine mode
        case quarantine(reason: String)
    }

    // MARK: - Initialization

    private init() {
        // Load previously selected role
        selectedRole = AppUserRole.load()
    }

    // MARK: - App Lifecycle

    /// Called on app launch to determine initial state
    func initialize() async {
        currentState = .loading

        // Check for saved role
        if let role = selectedRole {
            switch role {
            case .staff:
                await checkStaffSession()
            case .customer:
                await checkCustomerSession()
            }
        } else {
            // No role selected, show role selection
            currentState = .roleSelection
        }
    }

    /// Check for existing staff session
    private func checkStaffSession() async {
        await authManager.checkExistingSession()

        switch authManager.authState {
        case .authenticated:
            await syncPasscodeState()
            if !PasscodeService.shared.hasPasscode && !hasSeenPasscodeSetup {
                currentState = .passcodeSetup
            } else {
                currentState = .staffDashboard
            }
        case .quarantined(let reason):
            currentState = .quarantine(reason: reason)
        default:
            currentState = .staffLogin
        }
    }

    /// Check for existing customer session
    private func checkCustomerSession() async {
        await customerAuthManager.checkExistingSession()

        switch customerAuthManager.authState {
        case .authenticated:
            currentState = .customerPortal
        default:
            currentState = .customerLogin
        }
    }

    // MARK: - Role Selection

    /// User selected a role on the role selection screen
    func selectRole(_ role: AppUserRole) async {
        selectedRole = role

        switch role {
        case .staff:
            // Check if we have an existing session first
            if authManager.accessToken != nil {
                await checkStaffSession()
            } else {
                currentState = .staffLogin
            }
        case .customer:
            // Check if we have an existing session first
            if customerAuthManager.accessToken != nil {
                await checkCustomerSession()
            } else {
                currentState = .customerLogin
            }
        }
    }

    // MARK: - Auth State Changes

    /// Called when staff authentication succeeds
    func onStaffAuthenticated() async {
        // Sync passcode state from server (magic link response doesn't include passcode fields)
        await syncPasscodeState()

        switch authManager.authState {
        case .authenticated:
            if !PasscodeService.shared.hasPasscode && !hasSeenPasscodeSetup {
                currentState = .passcodeSetup
            } else {
                currentState = .staffDashboard
            }
        case .quarantined(let reason):
            currentState = .quarantine(reason: reason)
        default:
            break
        }
    }

    /// Fetches /me to sync passcode state from the server
    private func syncPasscodeState() async {
        do {
            let response: GetCurrentUserResponse = try await APIClient.shared.request(.me)
            PasscodeService.shared.syncFromAuthResponse(
                hasPasscode: response.hasPasscode,
                passcodeEnabled: response.passcodeEnabled,
                timeoutMinutes: response.passcodeTimeoutMinutes ?? 15
            )
        } catch {
            // Fall back to local state if /me fails
        }
    }

    /// Called when customer authentication succeeds
    func onCustomerAuthenticated() {
        currentState = .customerPortal
    }

    /// Called when staff logs out
    func onStaffLogout() {
        currentState = .staffLogin
    }

    /// Called when customer logs out
    func onCustomerLogout() {
        currentState = .customerLogin
    }

    // MARK: - Passcode Setup

    /// Whether the user has already seen the passcode setup prompt (persisted per user)
    private var hasSeenPasscodeSetup: Bool {
        guard let userId = authManager.currentUser?.id else { return false }
        return UserDefaults.standard.bool(forKey: "passcodeSetup_seen_\(userId)")
    }

    private func markPasscodeSetupSeen() {
        guard let userId = authManager.currentUser?.id else { return }
        UserDefaults.standard.set(true, forKey: "passcodeSetup_seen_\(userId)")
    }

    /// Called after user sets a passcode during first-login setup
    func onPasscodeSet() {
        markPasscodeSetupSeen()
        currentState = .staffDashboard
    }

    /// Called when user taps "Set up later" to skip passcode setup
    func onPasscodeSetupSkipped() {
        markPasscodeSetupSeen()
        currentState = .staffDashboard
    }

    // MARK: - Full Logout

    /// Full logout - clears everything and returns to role selection
    func fullLogout() async {
        // Log out from current role
        if let role = selectedRole {
            switch role {
            case .staff:
                await authManager.logout()
            case .customer:
                await customerAuthManager.logout()
            }
        }

        // Clear saved role
        AppUserRole.clear()
        selectedRole = nil

        // Return to role selection
        currentState = .roleSelection
    }

    /// Switch to a different role (logs out of current)
    func switchRole() async {
        await fullLogout()
    }
}
