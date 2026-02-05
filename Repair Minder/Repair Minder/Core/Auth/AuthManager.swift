//
//  AuthManager.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI
import UIKit

/// Staff authentication manager
/// Handles email/password + 2FA login, magic link login, and token management
/// Implements TokenProvider protocol for use with APIClient
@MainActor
final class AuthManager: ObservableObject, TokenProvider {

    // MARK: - Singleton

    static let shared = AuthManager()

    // MARK: - Published State

    /// Current authentication state
    @Published private(set) var authState: AuthState = .unknown

    /// Currently authenticated user
    @Published private(set) var currentUser: User?

    /// Current company
    @Published private(set) var currentCompany: Company?

    /// Whether the user has a password set
    @Published private(set) var hasPassword: Bool = false

    /// Loading state for UI
    @Published var isLoading: Bool = false

    /// Error message for UI
    @Published var errorMessage: String?

    // MARK: - Pending Login State (for 2FA flow)

    /// Pending user ID from initial login (for 2FA verification)
    private(set) var pendingUserId: String?

    /// Pending email from initial login (for 2FA verification)
    private(set) var pendingEmail: String?

    // MARK: - Authentication State

    enum AuthState: Equatable {
        /// Initial state, checking for stored tokens
        case unknown
        /// User needs to log in
        case unauthenticated
        /// User is authenticated
        case authenticated
        /// User's company is in quarantine mode
        case quarantined(reason: String)
    }

    // MARK: - TokenProvider Implementation

    var accessToken: String? {
        KeychainManager.shared.getAccessToken()
    }

    var refreshToken: String? {
        KeychainManager.shared.getRefreshToken()
    }

    func updateTokens(accessToken: String, refreshToken: String) {
        KeychainManager.shared.setAccessToken(accessToken)
        KeychainManager.shared.setRefreshToken(refreshToken)
    }

    func clearTokens() {
        KeychainManager.shared.clearStaffTokens()
        Task { @MainActor in
            self.authState = .unauthenticated
            self.currentUser = nil
            self.currentCompany = nil
            self.hasPassword = false
        }
    }

    // MARK: - Initialization

    private init() {
        // Register as token provider for APIClient
        Task { @MainActor in
            APIClient.shared.tokenProvider = self
        }
    }

    // MARK: - Check Existing Session

    /// Check if user has a valid session on app launch
    func checkExistingSession() async {
        guard accessToken != nil else {
            authState = .unauthenticated
            return
        }

        do {
            let response: GetCurrentUserResponse = try await APIClient.shared.request(.me)
            handleSuccessfulAuth(
                user: response.user,
                company: response.company,
                hasPassword: response.hasPassword
            )
            // Sync passcode state from server
            PasscodeService.shared.syncFromAuthResponse(
                hasPasscode: response.hasPasscode,
                passcodeEnabled: response.passcodeEnabled,
                timeoutMinutes: response.passcodeTimeoutMinutes ?? 15
            )
        } catch {
            // Token is invalid, clear it
            clearTokens()
            authState = .unauthenticated
        }
    }

    // MARK: - Email/Password Login (Step 1)

    /// Initiate login with email and password
    /// Returns after password validation, then requires 2FA code
    func login(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let request = StaffLoginRequest(email: email, password: password)
            let response: StaffLoginResponse = try await APIClient.shared.request(.login, body: request)

            // Store pending state for 2FA
            pendingUserId = response.userId
            pendingEmail = response.email

            // Request 2FA code
            try await request2FACode()

        } catch let error as APIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "An unexpected error occurred"
            throw error
        }
    }

    // MARK: - Request 2FA Code

    /// Request a new 2FA code to be sent via email
    func request2FACode() async throws {
        guard let userId = pendingUserId, let email = pendingEmail else {
            throw AuthError.noPendingLogin
        }

        let request = TwoFactorRequestBody(userId: userId, email: email)
        let _: TwoFactorRequestResponse = try await APIClient.shared.request(.twoFactorRequest, body: request)
    }

    // MARK: - Verify 2FA Code (Step 2)

    /// Verify the 2FA code to complete login
    func verify2FACode(_ code: String) async throws {
        guard let userId = pendingUserId else {
            throw AuthError.noPendingLogin
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let request = TwoFactorVerifyRequest(userId: userId, code: code)
            let response: StaffAuthResponse = try await APIClient.shared.request(.twoFactorVerify, body: request)

            // Store tokens
            updateTokens(accessToken: response.token, refreshToken: response.refreshToken)

            // Clear pending state
            clearPendingLogin()

            // Update state
            handleSuccessfulAuth(
                user: response.user,
                company: response.company,
                hasPassword: true
            )

        } catch let error as APIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "An unexpected error occurred"
            throw error
        }
    }

    // MARK: - Magic Link Login

    /// Request a magic link code to be sent via email
    func requestMagicLink(email: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let request = MagicLinkRequest(email: email)
            let _: MagicLinkRequestResponse = try await APIClient.shared.request(.magicLinkRequest, body: request)

            // Store email for verification step
            pendingEmail = email

        } catch let error as APIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "An unexpected error occurred"
            throw error
        }
    }

    /// Verify the magic link code to complete login
    func verifyMagicLinkCode(_ code: String) async throws {
        guard let email = pendingEmail else {
            throw AuthError.noPendingLogin
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let request = MagicLinkVerifyRequest(email: email, code: code)
            let response: StaffAuthResponse = try await APIClient.shared.request(.magicLinkVerifyCode, body: request)

            // Store tokens
            updateTokens(accessToken: response.token, refreshToken: response.refreshToken)

            // Clear pending state
            clearPendingLogin()

            // Update state
            handleSuccessfulAuth(
                user: response.user,
                company: response.company,
                hasPassword: false  // Magic link users may not have password
            )

        } catch let error as APIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "An unexpected error occurred"
            throw error
        }
    }

    // MARK: - Logout

    /// Log out the current user
    func logout() async {
        isLoading = true

        defer {
            isLoading = false
            clearTokens()
            clearPendingLogin()
        }

        // Unregister push token before logout
        await PushNotificationService.shared.unregisterToken()

        // Call logout endpoint (ignore errors - we'll clear local state anyway)
        do {
            try await APIClient.shared.requestVoid(.logout)
        } catch {
            print("[AuthManager] Logout API call failed: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func handleSuccessfulAuth(user: User, company: Company, hasPassword: Bool) {
        currentUser = user
        currentCompany = company
        self.hasPassword = hasPassword

        // Store user and company data
        KeychainManager.shared.setUser(user)
        KeychainManager.shared.setCompany(company)

        // Check for quarantine mode
        if user.isQuarantined {
            let reason = company.isPendingApproval
                ? "Your account is pending approval"
                : "Your company account has been suspended"
            authState = .quarantined(reason: reason)
        } else {
            authState = .authenticated

            // Request push notification permission after successful auth
            Task {
                await requestPushNotificationPermission()
            }
        }
    }

    /// Request push notification permission and register token
    private func requestPushNotificationPermission() async {
        let pushService = PushNotificationService.shared

        // Check current status first
        await pushService.checkAuthorizationStatus()

        // If not determined, request permission
        if pushService.authorizationStatus == .notDetermined {
            let granted = await pushService.requestAuthorization()
            if granted {
                print("[AuthManager] Push notification permission granted")
            }
        } else if pushService.authorizationStatus == .authorized {
            // Already authorized, just register for remote notifications
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func clearPendingLogin() {
        pendingUserId = nil
        pendingEmail = nil
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noPendingLogin
    case invalidCredentials
    case accountDeactivated
    case noPasswordSet

    var errorDescription: String? {
        switch self {
        case .noPendingLogin:
            return "No pending login session. Please start the login process again."
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountDeactivated:
            return "Your account has been deactivated"
        case .noPasswordSet:
            return "No password set. Please use Magic Link login."
        }
    }
}
