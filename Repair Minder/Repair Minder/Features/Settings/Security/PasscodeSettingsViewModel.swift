//
//  PasscodeSettingsViewModel.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import SwiftUI

@MainActor
final class PasscodeSettingsViewModel: ObservableObject {
    @Published var showChangePasscode = false
    @Published var showResetConfirmation = false
    @Published var showResetFlow = false
    @Published var showDisableConfirmation = false
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

    func toggleEnabled(_ enabled: Bool) {
        if !enabled {
            // Disabling requires confirmation
            showDisableConfirmation = true
            return
        }
        Task {
            do {
                try await passcodeService.togglePasscodeEnabled(true)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    func confirmDisable() {
        Task {
            do {
                try await passcodeService.togglePasscodeEnabled(false)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    func requestReset() {
        Task {
            do {
                try await passcodeService.requestPasscodeReset()
                showResetFlow = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
