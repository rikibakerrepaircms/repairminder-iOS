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

    /// True once the user has unlocked (Face ID or passcode) since this process launched.
    /// Prevents the cold-launch re-arm in AppState from re-locking after a successful unlock.
    private(set) var hasUnlockedSinceLaunch = false
    @Published private(set) var biometricBlocked: Bool = false

    /// Number of consecutive wrong passcode entries that disables biometric unlock
    /// until a correct passcode is entered. Survives force-quit (keychain-backed).
    static let maxFailedBeforeBiometricBlock = 5

    /// Set by DeepLinkHandler when the user taps a reset link. Observed at the app
    /// root to present the "set new passcode" sheet above the lock overlay.
    @Published var pendingResetToken: String?

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
        biometricBlocked = keychain.getPasscodeFailedCount() >= Self.maxFailedBeforeBiometricBlock
        // Auto-lock on cold launch when "On App Close" is set — but ONLY if a staff
        // session actually exists. A logged-out app must never show the passcode/Face ID
        // lock, even if stale passcode keychain data lingers (iOS keychain survives app
        // deletion, so leftover state can outlive a logout). See clearLocalData().
        let hasSession = keychain.getAccessToken() != nil
        if hasSession && passcodeEnabled && timeoutMinutes == 0 {
            isLocked = true
        }
    }

    /// Called after login — syncs server state to local
    func syncFromAuthResponse(hasPasscode: Bool, passcodeEnabled: Bool, timeoutMinutes: Int) {
        self.hasPasscode = hasPasscode
        self.passcodeEnabled = passcodeEnabled
        keychain.setPasscodeEnabled(passcodeEnabled)
        // The shared passcode may have been cleared elsewhere (e.g. from the web). Drop the
        // stale cached credential so local verification doesn't use an old hash.
        if !hasPasscode {
            keychain.clearPasscodeCredential()
        }
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
        passcodeEnabled = true
        keychain.setPasscodeEnabled(true)
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

    /// Verify an entered passcode. Uses the fast local hash when cached, otherwise
    /// falls back to the server (which re-caches the hash on success).
    func verifyPasscodeAllowingServer(_ passcode: String) async -> Bool {
        if keychain.getPasscodeHash() != nil {
            return verifyPasscode(passcode)
        }
        do {
            try await verifyAndCachePasscode(passcode)
            hasPasscode = true
            return true
        } catch {
            return false
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

    func resetPasscode(token: String, newPasscode: String) async throws {
        let body = ResetPasscodeRequest(token: token, newPasscode: newPasscode)
        let response: ResetPasscodeResponse = try await APIClient.shared.request(.resetPasscode, body: body)
        // Update local cache
        if let hash = response.passcodeHash, let salt = response.passcodeSalt {
            keychain.setPasscodeHash(hash)
            keychain.setPasscodeSalt(salt)
        }
        hasPasscode = true
        resetFailedAttempts()
    }

    // MARK: - Toggle Enabled

    func togglePasscodeEnabled(_ enabled: Bool) async throws {
        let body = TogglePasscodeEnabledRequest(enabled: enabled)
        let response: TogglePasscodeEnabledResponse = try await APIClient.shared.request(.togglePasscodeEnabled, body: body)
        passcodeEnabled = enabled
        keychain.setPasscodeEnabled(enabled)
        // If the server cleared the shared passcode (both app + web locks now off),
        // reflect it locally so this matches the web behaviour.
        if response.hasPasscode == false {
            hasPasscode = false
            keychain.clearPasscodeCredential()
            resetFailedAttempts()
        }
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
        guard passcodeEnabled else { return }
        isLocked = true
    }

    func unlockApp() {
        isLocked = false
        hasUnlockedSinceLaunch = true
    }

    func shouldLockOnForeground(backgroundDuration: TimeInterval) -> Bool {
        let timeoutSeconds = TimeInterval(timeoutMinutes) * 60
        return hasPasscode && passcodeEnabled && backgroundDuration >= timeoutSeconds
    }

    func recordFailedAttempt() {
        let count = keychain.getPasscodeFailedCount() + 1
        keychain.setPasscodeFailedCount(count)
        biometricBlocked = count >= Self.maxFailedBeforeBiometricBlock
    }

    func resetFailedAttempts() {
        keychain.setPasscodeFailedCount(0)
        biometricBlocked = false
    }

    // MARK: - Cleanup (logout)

    func clearLocalData() {
        keychain.clearPasscodeData()
        hasPasscode = false
        passcodeEnabled = false
        isBiometricEnabled = false
        isLocked = false
        timeoutMinutes = 15
        biometricBlocked = false
    }

    // MARK: - Hashing (matches backend)

    private func hashPasscode(_ passcode: String, salt: String) -> String {
        let input = passcode + salt
        guard let data = input.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
