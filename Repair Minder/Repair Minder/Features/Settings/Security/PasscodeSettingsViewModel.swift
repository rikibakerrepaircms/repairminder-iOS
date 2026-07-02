//
//  PasscodeSettingsViewModel.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import SwiftUI

@MainActor
final class PasscodeSettingsViewModel: ObservableObject {
    @Published var showCreatePasscode = false
    @Published var showChangePasscode = false
    @Published var showResetConfirmation = false
    @Published var showResetLinkSent = false
    @Published var showVerifyForDisable = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var selectedTimeout: Int

    private let passcodeService = PasscodeService.shared

    struct TimeoutOption {
        let minutes: Int
        let label: String
    }

    let timeoutOptions: [TimeoutOption] = [
        TimeoutOption(minutes: 0,  label: "On App Close"),
        TimeoutOption(minutes: 1,  label: "1 minute"),
        TimeoutOption(minutes: 5,  label: "5 minutes"),
        TimeoutOption(minutes: 15, label: "15 minutes"),
        TimeoutOption(minutes: 30, label: "30 minutes"),
        TimeoutOption(minutes: 60, label: "1 hour"),
    ]

    init() {
        selectedTimeout = PasscodeService.shared.timeoutMinutes
    }

    func updateTimeout(_ minutes: Int) {
        Task {
            do {
                try await passcodeService.updateTimeout(minutes)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                // Revert picker
                selectedTimeout = passcodeService.timeoutMinutes
            }
        }
    }

    // MARK: - Passcode enable/disable

    func toggleEnabled(_ enabled: Bool) {
        if enabled {
            Task {
                do {
                    try await passcodeService.togglePasscodeEnabled(true)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            return
        }
        // Turning the passcode lock OFF must be authenticated first.
        if passcodeService.isBiometricEnabled && passcodeService.isBiometricAvailable {
            Task {
                let result = await passcodeService.authenticateWithBiometric()
                if case .success = result {
                    await disablePasscode()
                } else {
                    // Cancelled/failed — revert the toggle to its real (still-on) state.
                    passcodeService.objectWillChange.send()
                }
            }
        } else {
            showVerifyForDisable = true
        }
    }

    /// Called by VerifyPasscodeView once the current passcode is confirmed.
    func onDisableVerified() {
        Task { await disablePasscode() }
    }

    private func disablePasscode() async {
        do {
            try await passcodeService.togglePasscodeEnabled(false)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Biometric enable/disable

    func setBiometricEnabled(_ enabled: Bool) {
        if enabled {
            passcodeService.setBiometric(enabled: true)
            return
        }
        // Turning Face ID / Touch ID OFF requires a successful scan first.
        Task {
            let result = await passcodeService.authenticateWithBiometric()
            if case .success = result {
                passcodeService.setBiometric(enabled: false)
            } else {
                // Cancelled/failed — revert the toggle to its real (still-on) state.
                passcodeService.objectWillChange.send()
            }
        }
    }

    func requestReset() {
        Task {
            do {
                try await passcodeService.requestPasscodeReset()
                showResetLinkSent = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
