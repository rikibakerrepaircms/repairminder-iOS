//
//  PasscodeService.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import Foundation
import LocalAuthentication
import CryptoKit

@MainActor
final class PasscodeService: ObservableObject {
    static let shared = PasscodeService()

    // MARK: - Published State

    @Published private(set) var hasPasscode: Bool = false
    @Published private(set) var passcodeEnabled: Bool = false
    @Published private(set) var isBiometricEnabled: Bool = false
    @Published private(set) var biometricType: BiometricType = .none
    @Published private(set) var timeoutMinutes: Int = 15
    @Published var isLocked: Bool = false

    // MARK: - Types

    enum BiometricType {
        case none, touchID, faceID

        var displayName: String {
            switch self {
            case .none: return "Biometric"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            }
        }

        var systemImage: String {
            switch self {
            case .none: return "lock"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            }
        }
    }

    enum PasscodeError: LocalizedError {
        case incorrectPasscode
        case biometricNotAvailable
        case biometricFailed(String)
        case biometricCancelled
        case apiError(String)
        case noPasscodeSet

        var errorDescription: String? {
            switch self {
            case .incorrectPasscode: return "Incorrect passcode"
            case .biometricNotAvailable: return "Biometric authentication not available"
            case .biometricFailed(let msg): return msg
            case .biometricCancelled: return "Authentication cancelled"
            case .apiError(let msg): return msg
            case .noPasscodeSet: return "No passcode set"
            }
        }
    }

    // MARK: - Private

    private let keychain = KeychainManager.shared

    private init() {
        loadLocalState()
        checkBiometricAvailability()
    }

    // MARK: - Local State

    func loadLocalState() {
        hasPasscode = keychain.getPasscodeHash() != nil
        passcodeEnabled = keychain.isPasscodeEnabled()
        isBiometricEnabled = keychain.isBiometricEnabled()
        timeoutMinutes = keychain.getPasscodeTimeout() ?? 15
        // Auto-lock on cold launch when "On App Close" is set
        if hasPasscode && passcodeEnabled && timeoutMinutes == 0 {
            isLocked = true
        }
    }

    /// Called after login — syncs server state to local
    func syncFromAuthResponse(hasPasscode: Bool, passcodeEnabled: Bool, timeoutMinutes: Int) {
        self.hasPasscode = hasPasscode
        self.passcodeEnabled = passcodeEnabled
        keychain.setPasscodeEnabled(passcodeEnabled)
        // Preserve local "On App Close" (0) setting — it's not stored on the server
        let localTimeout = keychain.getPasscodeTimeout()
        if localTimeout == 0 {
            self.timeoutMinutes = 0
        } else {
            self.timeoutMinutes = timeoutMinutes
            keychain.setPasscodeTimeout(timeoutMinutes)
        }
    }

    // MARK: - Biometric

    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }
        switch context.biometryType {
        case .faceID:  biometricType = .faceID
        case .touchID: biometricType = .touchID
        default:       biometricType = .none
        }
    }

    var isBiometricAvailable: Bool { biometricType != .none }

    func setBiometric(enabled: Bool) {
        keychain.setBiometricEnabled(enabled)
        isBiometricEnabled = enabled
    }

    func authenticateWithBiometric() async -> Result<Void, PasscodeError> {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Repair Minder"
            )
            return success ? .success(()) : .failure(.biometricFailed("Authentication failed"))
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                return .failure(.biometricCancelled)
            default:
                return .failure(.biometricFailed(error.localizedDescription))
            }
        } catch {
            return .failure(.biometricFailed(error.localizedDescription))
        }
    }

    // MARK: - Set Passcode (first time, server-side)

    func setPasscode(_ passcode: String) async throws {
        let body = SetPasscodeRequest(passcode: passcode)
        let _: SetPasscodeResponse = try await APIClient.shared.request(.setPasscode, body: body)
        // Verify immediately to get hash + salt for local cache
        try await verifyAndCachePasscode(passcode)
        hasPasscode = true
    }

    // MARK: - Verify Passcode

    /// Verify locally first (fast), fallback to server
    func verifyPasscode(_ passcode: String) -> Bool {
        guard let storedHash = keychain.getPasscodeHash(),
              let salt = keychain.getPasscodeSalt() else {
            return false
        }
        let inputHash = hashPasscode(passcode, salt: salt)
        return inputHash == storedHash
    }

    /// Verify against server and cache hash locally
    func verifyAndCachePasscode(_ passcode: String) async throws {
        let body = VerifyPasscodeRequest(passcode: passcode)
        let response: VerifyPasscodeResponse = try await APIClient.shared.request(.verifyPasscode, body: body)
        guard response.valid else {
            throw PasscodeError.incorrectPasscode
        }
        // Cache hash + salt locally
        if let hash = response.passcodeHash, let salt = response.passcodeSalt {
            keychain.setPasscodeHash(hash)
            keychain.setPasscodeSalt(salt)
        }
    }

    // MARK: - Change Passcode

    func changePasscode(current: String, new: String) async throws {
        let body = ChangePasscodeRequest(currentPasscode: current, newPasscode: new)
        let response: ChangePasscodeResponse = try await APIClient.shared.request(.changePasscode, body: body)
        // Update local cache
        if let hash = response.passcodeHash, let salt = response.passcodeSalt {
            keychain.setPasscodeHash(hash)
            keychain.setPasscodeSalt(salt)
        }
    }

    // MARK: - Reset Passcode

    func requestPasscodeReset() async throws {
        let _: ResetPasscodeRequestResponse = try await APIClient.shared.request(.resetPasscodeRequest, body: ResetPasscodeRequestBody())
    }

    func resetPasscode(code: String, newPasscode: String) async throws {
        let body = ResetPasscodeRequest(code: code, newPasscode: newPasscode)
        let response: ResetPasscodeResponse = try await APIClient.shared.request(.resetPasscode, body: body)
        // Update local cache
        if let hash = response.passcodeHash, let salt = response.passcodeSalt {
            keychain.setPasscodeHash(hash)
            keychain.setPasscodeSalt(salt)
        }
        hasPasscode = true
    }

    // MARK: - Toggle Enabled

    func togglePasscodeEnabled(_ enabled: Bool) async throws {
        let body = TogglePasscodeEnabledRequest(enabled: enabled)
        let _: TogglePasscodeEnabledResponse = try await APIClient.shared.request(.togglePasscodeEnabled, body: body)
        passcodeEnabled = enabled
        keychain.setPasscodeEnabled(enabled)
    }

    // MARK: - Timeout

    func updateTimeout(_ minutes: Int) async throws {
        // 0 means "On App Close" — handled locally only (API requires 1-1440)
        if minutes > 0 {
            let body = PasscodeTimeoutRequest(minutes: minutes)
            let _: PasscodeTimeoutResponse = try await APIClient.shared.request(.passcodeTimeout, body: body)
        }
        timeoutMinutes = minutes
        keychain.setPasscodeTimeout(minutes)
    }

    // MARK: - Lock Management

    func lockApp() {
        guard hasPasscode && passcodeEnabled else { return }
        isLocked = true
    }

    func unlockApp() {
        isLocked = false
    }

    func shouldLockOnForeground(backgroundDuration: TimeInterval) -> Bool {
        let timeoutSeconds = TimeInterval(timeoutMinutes) * 60
        return hasPasscode && passcodeEnabled && backgroundDuration >= timeoutSeconds
    }

    // MARK: - Cleanup (logout)

    func clearLocalData() {
        keychain.clearPasscodeData()
        hasPasscode = false
        passcodeEnabled = false
        isBiometricEnabled = false
        isLocked = false
        timeoutMinutes = 15
    }

    // MARK: - Hashing (matches backend)

    private func hashPasscode(_ passcode: String, salt: String) -> String {
        let input = passcode + salt
        guard let data = input.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
