//
//  PasscodeLockViewModel.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import SwiftUI

@MainActor
final class PasscodeLockViewModel: ObservableObject {
    @Published var enteredDigits: String = ""
    @Published var shakeCount: Int = 0
    @Published var showForgotAlert: Bool = false
    @Published var showResetFlow: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var errorMessage: String?

    let passcodeLength = 6
    private let passcodeService = PasscodeService.shared

    var canUseBiometric: Bool {
        passcodeService.isBiometricEnabled && passcodeService.isBiometricAvailable
    }
    var biometricIcon: String { passcodeService.biometricType.systemImage }

    func appendDigit(_ digit: String) {
        guard enteredDigits.count < passcodeLength else { return }
        enteredDigits += digit
        errorMessage = nil
        if enteredDigits.count == passcodeLength { verifyPasscode() }
    }

    func deleteDigit() {
        guard !enteredDigits.isEmpty else { return }
        enteredDigits.removeLast()
    }

    private func verifyPasscode() {
        if passcodeService.verifyPasscode(enteredDigits) {
            passcodeService.unlockApp()
        } else {
            enteredDigits = ""
            errorMessage = "Incorrect passcode"
            withAnimation { shakeCount += 1 }
        }
    }

    func attemptBiometricOnAppear() {
        guard canUseBiometric, !isAuthenticating else { return }
        authenticateWithBiometric()
    }

    func authenticateWithBiometric() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            let result = await passcodeService.authenticateWithBiometric()
            isAuthenticating = false
            switch result {
            case .success: passcodeService.unlockApp()
            case .failure(.biometricCancelled): break
            case .failure(let error): errorMessage = error.errorDescription
            }
        }
    }

    func requestPasscodeReset() {
        Task {
            do {
                try await passcodeService.requestPasscodeReset()
                showResetFlow = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func forceLogout() {
        passcodeService.clearLocalData()
        Task {
            if AuthManager.shared.authState == .authenticated {
                await AuthManager.shared.logout()
                AppState.shared.onStaffLogout()
            } else {
                await AppState.shared.fullLogout()
            }
        }
    }
}
