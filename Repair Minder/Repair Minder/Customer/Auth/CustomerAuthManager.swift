//
//  CustomerAuthManager.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import os.log

/// Customer authentication manager using magic link authentication
@MainActor
@Observable
final class CustomerAuthManager {
    private(set) var isAuthenticated: Bool = false
    private(set) var isLoading: Bool = true
    private(set) var customerEmail: String?
    private(set) var customerId: String?
    var error: String?

    private let keychain = KeychainManager.shared
    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder-Customer", category: "CustomerAuth")

    init() {
        Task {
            await checkExistingSession()
        }
    }

    // MARK: - Session Management

    /// Check for an existing session on app launch
    func checkExistingSession() async {
        isLoading = true
        defer { isLoading = false }

        guard let token = keychain.getString(for: .accessToken),
              let email = keychain.getString(for: .userId) else {
            logger.debug("No stored customer token, not authenticated")
            return
        }

        // Configure API client with token
        await APIClient.shared.setAuthTokenProvider { [weak self] in
            self?.keychain.getString(for: .accessToken)
        }

        customerEmail = email
        isAuthenticated = true
        logger.debug("Customer session restored for: \(email)")
    }

    // MARK: - Magic Link Authentication

    /// Request a verification code to be sent to the customer's email
    func requestCode(email: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await APIClient.shared.requestVoid(.customerRequestMagicLink(email: email))
            logger.debug("Verification code sent to: \(email)")
            return true
        } catch let apiError as APIError {
            logger.error("Failed to send verification code: \(apiError.localizedDescription)")
            error = "Failed to send verification code. Please try again."
            return false
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            self.error = "An unexpected error occurred. Please try again."
            return false
        }
    }

    /// Verify the code and complete login
    func verifyCode(email: String, code: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: CustomerVerifyResponse = try await APIClient.shared.request(
                .customerVerifyCode(email: email, code: code),
                responseType: CustomerVerifyResponse.self
            )

            // Store credentials
            try keychain.save(response.token, for: .accessToken)
            try keychain.save(email, for: .userId)

            // Configure API client
            await APIClient.shared.setAuthTokenProvider { [weak self] in
                self?.keychain.getString(for: .accessToken)
            }

            customerEmail = email
            customerId = response.customerId
            isAuthenticated = true

            logger.debug("Customer login successful for: \(email)")

            // Request push notification permission
            await NotificationManager.shared.requestPermission()

        } catch let apiError as APIError {
            logger.error("Verification failed: \(apiError.localizedDescription)")
            switch apiError {
            case .unauthorized:
                error = "Invalid or expired code. Please try again."
            case .rateLimited:
                error = "Too many attempts. Please wait a moment and try again."
            default:
                error = "Verification failed. Please check your code and try again."
            }
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            self.error = "An unexpected error occurred. Please try again."
        }
    }

    // MARK: - Logout

    /// Logout the customer
    func logout() async {
        logger.debug("Customer logging out")

        // Unregister device token
        await NotificationManager.shared.unregisterToken()

        // Try to notify server (best effort)
        try? await APIClient.shared.requestVoid(.customerLogout())

        // Clear local state
        keychain.deleteAll()
        customerEmail = nil
        customerId = nil
        isAuthenticated = false
        error = nil
    }
}

// MARK: - Response Types

struct CustomerVerifyResponse: Codable {
    let token: String
    let customerId: String
    let clientId: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case token, customerId, clientId, email
    }
}
