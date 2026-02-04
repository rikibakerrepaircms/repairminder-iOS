//
//  AuthManager.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation
import os.log

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    private(set) var isAuthenticated: Bool = false
    private(set) var currentUser: User?
    private(set) var currentCompany: Company?
    private(set) var isLoading: Bool = true

    private let keychain = KeychainManager.shared
    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "Auth")

    private var refreshTask: Task<Void, Never>?

    private init() {
        // Configure API client with token provider
        Task {
            await APIClient.shared.setAuthTokenProvider { [weak self] in
                self?.keychain.getString(for: .accessToken)
            }
        }
    }

    // MARK: - Public API

    /// Check authentication status on app launch
    func checkAuthStatus() async {
        isLoading = true
        defer { isLoading = false }

        guard keychain.getString(for: .accessToken) != nil else {
            logger.debug("No stored token, user not authenticated")
            await clearAuth()
            return
        }

        // Check if token is expired
        if let expiresAt = keychain.getDate(for: .tokenExpiresAt),
           expiresAt < Date() {
            logger.debug("Token expired, attempting refresh")
            do {
                try await refreshToken()
            } catch {
                logger.error("Token refresh failed: \(error.localizedDescription)")
                await clearAuth()
                return
            }
        }

        // Fetch current user to validate token
        do {
            let response: MeResponse = try await APIClient.shared.request(
                .me(),
                responseType: MeResponse.self
            )
            currentUser = response.user
            currentCompany = response.company
            isAuthenticated = true
            logger.debug("Auth restored for user: \(response.user.email)")

            // Schedule proactive token refresh
            scheduleTokenRefresh()
        } catch let error as APIError where error.requiresReauth {
            logger.error("Token invalid, clearing auth")
            await clearAuth()
        } catch {
            logger.error("Failed to fetch current user: \(error.localizedDescription)")
            // Keep trying with existing token if it's a network error
            if let apiError = error as? APIError, case .offline = apiError {
                // Offline, but we have a token - assume authenticated
                isAuthenticated = true
            } else {
                await clearAuth()
            }
        }
    }

    /// Request a magic link code to be sent to the email
    func requestMagicLink(email: String) async throws {
        logger.debug("Requesting magic link for: \(email)")

        let _: MagicLinkRequestResponse = try await APIClient.shared.request(
            .requestMagicLink(email: email),
            responseType: MagicLinkRequestResponse.self
        )

        logger.debug("Magic link sent to: \(email)")
    }

    /// Verify the magic link code and complete login
    func verifyMagicLinkCode(email: String, code: String) async throws {
        logger.debug("Verifying magic link code for: \(email)")

        let response: MagicLinkVerifyResponse = try await APIClient.shared.request(
            .verifyMagicLinkCode(email: email, code: code),
            responseType: MagicLinkVerifyResponse.self
        )

        // Store credentials
        try await storeCredentials(
            token: response.token,
            refreshToken: response.refreshToken,
            expiresIn: response.expiresIn
        )

        // Update state
        currentUser = response.user
        currentCompany = response.company
        isAuthenticated = true

        logger.debug("Login successful for: \(response.user.email)")

        // Schedule proactive token refresh
        scheduleTokenRefresh()

        // Request push notification permission after successful login
        await NotificationManager.shared.requestPermission()
    }

    /// Logout the current user
    func logout() async {
        logger.debug("Logging out user")

        // Unregister device token for push notifications
        await NotificationManager.shared.unregisterToken()

        // Try to notify server (best effort)
        try? await APIClient.shared.requestVoid(.logout())

        await clearAuth()
    }

    /// Refresh the access token
    func refreshToken() async throws {
        guard let refreshToken = keychain.getString(for: .refreshToken) else {
            throw AuthError.noRefreshToken
        }

        logger.debug("Refreshing access token")

        let response: RefreshResponse = try await APIClient.shared.request(
            .refreshToken(refreshToken: refreshToken),
            responseType: RefreshResponse.self
        )

        try await storeCredentials(
            token: response.token,
            refreshToken: response.refreshToken,
            expiresIn: response.expiresIn
        )

        logger.debug("Token refreshed successfully")
    }

    // MARK: - Private

    private func storeCredentials(token: String, refreshToken: String, expiresIn: Int) async throws {
        try keychain.save(token, for: .accessToken)
        try keychain.save(refreshToken, for: .refreshToken)

        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        try keychain.save(expiresAt, for: .tokenExpiresAt)
    }

    private func clearAuth() async {
        refreshTask?.cancel()
        refreshTask = nil

        keychain.deleteAll()
        currentUser = nil
        currentCompany = nil
        isAuthenticated = false
    }

    private func scheduleTokenRefresh() {
        refreshTask?.cancel()

        guard let expiresAt = keychain.getDate(for: .tokenExpiresAt) else { return }

        // Refresh 60 seconds before expiry
        let refreshTime = expiresAt.addingTimeInterval(-60)
        let delay = refreshTime.timeIntervalSinceNow

        guard delay > 0 else {
            // Token already needs refresh
            Task {
                try? await refreshToken()
            }
            return
        }

        logger.debug("Scheduling token refresh in \(Int(delay)) seconds")

        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))

            guard !Task.isCancelled else { return }

            do {
                try await self?.refreshToken()
                self?.scheduleTokenRefresh()
            } catch {
                self?.logger.error("Scheduled token refresh failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noRefreshToken
    case invalidCode
    case codeSendFailed(String)

    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidCode:
            return "Invalid verification code"
        case .codeSendFailed(let message):
            return message
        }
    }
}
