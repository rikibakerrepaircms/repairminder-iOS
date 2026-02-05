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
            currentState = .staffDashboard
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
    func onStaffAuthenticated() {
        switch authManager.authState {
        case .authenticated:
            currentState = .staffDashboard
        case .quarantined(let reason):
            currentState = .quarantine(reason: reason)
        default:
            break
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
