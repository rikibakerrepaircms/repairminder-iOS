//
//  CustomerAuthManager.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI
import UIKit

/// Customer authentication manager
/// Handles magic link login with multi-company support
@MainActor
final class CustomerAuthManager: ObservableObject {

    // MARK: - Singleton

    static let shared = CustomerAuthManager()

    // MARK: - Published State

    /// Current authentication state
    @Published private(set) var authState: CustomerAuthState = .unknown

    /// Currently authenticated client
    @Published private(set) var currentCustomerClient: CustomerClient?

    /// Current company
    @Published private(set) var currentCompany: Company?

    /// Loading state for UI
    @Published var isLoading: Bool = false

    /// Error message for UI
    @Published var errorMessage: String?

    // MARK: - Pending Login State

    /// Pending email for code verification
    private(set) var pendingEmail: String?

    /// Pending code for company selection
    private(set) var pendingCode: String?

    /// Available companies for selection (multi-company scenario)
    @Published private(set) var availableCompanies: [CompanySelectionItem] = []

    // MARK: - Authentication State

    enum CustomerAuthState: Equatable {
        /// Initial state, checking for stored tokens
        case unknown
        /// User needs to log in
        case unauthenticated
        /// Waiting for magic link code entry
        case awaitingCode
        /// Customer needs to select a company
        case companySelection
        /// User is authenticated
        case authenticated
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Token Access

    var accessToken: String? {
        KeychainManager.shared.getCustomerAccessToken()
    }

    // MARK: - Check Existing Session

    /// Check if customer has a valid session on app launch
    func checkExistingSession() async {
        guard accessToken != nil else {
            authState = .unauthenticated
            return
        }

        do {
            let response: CustomerGetCurrentUserResponse = try await performAuthenticatedRequest(.customerMe)
            currentCustomerClient = response.client
            currentCompany = response.company
            KeychainManager.shared.setCustomerClient(response.client)
            KeychainManager.shared.setCompany(response.company)
            authState = .authenticated
        } catch {
            // Token is invalid, clear it
            clearSession()
            authState = .unauthenticated
        }
    }

    // MARK: - Request Magic Link

    /// Request a magic link code to be sent via email
    func requestMagicLink(email: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let request = CustomerMagicLinkRequest(email: email, companyId: nil)
            let _: CustomerMagicLinkResponse = try await APIClient.shared.request(.customerMagicLinkRequest, body: request)

            // Store email for verification step
            pendingEmail = email
            authState = .awaitingCode

        } catch let error as APIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "An unexpected error occurred"
            throw error
        }
    }

    // MARK: - Verify Code

    /// Verify the magic link code
    /// May return authenticated or require company selection
    func verifyCode(_ code: String) async throws {
        guard let email = pendingEmail else {
            throw CustomerAuthError.noPendingLogin
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let request = CustomerVerifyCodeRequest(email: email, code: code, companyId: nil)
            let response: CustomerVerifyCodeResponse = try await APIClient.shared.request(.customerVerifyCode, body: request)

            if response.needsCompanySelection {
                // Multi-company scenario - store state and wait for selection
                pendingCode = response.code ?? code
                availableCompanies = response.companies ?? []
                authState = .companySelection
            } else if let token = response.token,
                      let client = response.client,
                      let company = response.company {
                // Single company - login complete
                handleSuccessfulAuth(token: token, client: client, company: company)
            } else {
                throw CustomerAuthError.invalidResponse
            }

        } catch let error as APIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "An unexpected error occurred"
            throw error
        }
    }

    // MARK: - Select Company

    /// Complete login by selecting a company (multi-company scenario)
    func selectCompany(_ companyId: String) async throws {
        guard let email = pendingEmail, let code = pendingCode else {
            throw CustomerAuthError.noPendingLogin
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let request = CustomerVerifyCodeRequest(email: email, code: code, companyId: companyId)
            let response: CustomerAuthResponse = try await APIClient.shared.request(.customerVerifyCode, body: request)

            handleSuccessfulAuth(token: response.token, client: response.client, company: response.company)

        } catch let error as APIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "An unexpected error occurred"
            throw error
        }
    }

    // MARK: - Logout

    /// Log out the current customer
    func logout() async {
        isLoading = true

        defer {
            isLoading = false
            clearSession()
            clearPendingLogin()
        }

        // Unregister push token before logout
        await PushNotificationService.shared.unregisterToken()

        // Call logout endpoint (ignore errors - we'll clear local state anyway)
        do {
            try await performAuthenticatedRequestVoid(.customerLogout)
        } catch {
            #if DEBUG
            print("[CustomerAuthManager] Logout API call failed: \(error)")
            #endif
        }
    }

    // MARK: - Cancel Login

    /// Cancel the current login process and return to start
    func cancelLogin() {
        clearPendingLogin()
        authState = .unauthenticated
    }

    // MARK: - Private Helpers

    private func handleSuccessfulAuth(token: String, client: CustomerClient, company: Company) {
        // Store token
        KeychainManager.shared.setCustomerAccessToken(token)

        // Store client and company data
        KeychainManager.shared.setCustomerClient(client)
        KeychainManager.shared.setCompany(company)

        // Update state
        currentCustomerClient = client
        currentCompany = company
        authState = .authenticated

        // Clear pending state
        clearPendingLogin()

        // Request push notification permission
        Task {
            await requestPushNotificationPermission()
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
                #if DEBUG
                print("[CustomerAuthManager] Push notification permission granted")
                #endif
            }
        } else if pushService.authorizationStatus == .authorized {
            // Already authorized, just register for remote notifications
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func clearSession() {
        KeychainManager.shared.clearCustomerTokens()
        currentCustomerClient = nil
        currentCompany = nil
        authState = .unauthenticated
    }

    private func clearPendingLogin() {
        pendingEmail = nil
        pendingCode = nil
        availableCompanies = []
    }

    // MARK: - Authenticated Requests

    /// Perform an authenticated request with customer token
    private func performAuthenticatedRequest<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        guard let token = accessToken else {
            throw APIError.unauthorized
        }

        // Create a custom request with customer token
        var request = URLRequest(url: URL(string: "https://api.repairminder.com\(endpoint.path)")!)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)

        guard apiResponse.success, let responseData = apiResponse.data else {
            throw APIError.serverError(message: apiResponse.error ?? "Unknown error", code: apiResponse.code)
        }

        return responseData
    }

    /// Perform an authenticated void request with customer token
    private func performAuthenticatedRequestVoid(_ endpoint: APIEndpoint) async throws {
        guard let token = accessToken else {
            throw APIError.unauthorized
        }

        var request = URLRequest(url: URL(string: "https://api.repairminder.com\(endpoint.path)")!)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
    }
}

// MARK: - Customer Auth Errors

enum CustomerAuthError: LocalizedError {
    case noPendingLogin
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noPendingLogin:
            return "No pending login session. Please start the login process again."
        case .invalidResponse:
            return "Received an unexpected response from the server."
        }
    }
}
