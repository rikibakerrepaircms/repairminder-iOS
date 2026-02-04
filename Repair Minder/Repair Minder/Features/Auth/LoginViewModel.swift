//
//  LoginViewModel.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation
import os.log

@MainActor
@Observable
final class LoginViewModel {
    var email: String = ""
    var verificationCode: String = ""
    var isLoading: Bool = false
    var error: String?
    var showCodeEntry: Bool = false

    private var pendingEmail: String = ""

    private let authManager = AuthManager.shared
    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "Login")

    var isEmailValid: Bool {
        email.trimmed.isValidEmail
    }

    var isCodeValid: Bool {
        verificationCode.count == 6 && verificationCode.allSatisfy(\.isNumber)
    }

    /// Request a magic link code to be sent
    func sendCode() async {
        guard isEmailValid else {
            error = "Please enter a valid email address"
            return
        }

        isLoading = true
        error = nil

        do {
            try await authManager.requestMagicLink(email: email.trimmed)
            pendingEmail = email.trimmed
            showCodeEntry = true
            logger.debug("Magic link code requested successfully")
        } catch let apiError as APIError {
            error = apiError.localizedDescription
            logger.error("Failed to send code: \(apiError.localizedDescription)")
        } catch {
            self.error = "Failed to send code. Please try again."
            logger.error("Unexpected error sending code: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Verify the entered code
    func verifyCode() async {
        guard isCodeValid else {
            error = "Please enter a valid 6-digit code"
            return
        }

        isLoading = true
        error = nil

        do {
            try await authManager.verifyMagicLinkCode(
                email: pendingEmail,
                code: verificationCode
            )
            logger.debug("Code verified successfully")
            // Navigation handled by AppState observing AuthManager
        } catch let apiError as APIError {
            error = apiError.localizedDescription
            verificationCode = ""
            logger.error("Code verification failed: \(apiError.localizedDescription)")
        } catch {
            self.error = "Invalid code. Please try again."
            verificationCode = ""
            logger.error("Unexpected error verifying code: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Go back to email entry
    func cancelCodeEntry() {
        showCodeEntry = false
        verificationCode = ""
        error = nil
    }

    /// Resend the verification code
    func resendCode() async {
        verificationCode = ""
        error = nil
        await sendCode()
    }
}
