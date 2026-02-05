//
//  ResetPasscodeView.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import SwiftUI

struct ResetPasscodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .enterCode
    @State private var resetCode: String = ""
    @State private var newPasscode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var errorMessage: String?
    @State private var shakeCount: Int = 0
    @State private var isLoading: Bool = false

    private let passcodeLength = 6
    private let passcodeService = PasscodeService.shared

    enum Step: String {
        case enterCode = "Enter reset code from email"
        case enterNew = "Enter new passcode"
        case confirmNew = "Confirm new passcode"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(step.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)

                PINDotsView(
                    enteredCount: currentInput.count,
                    totalCount: passcodeLength,
                    shakeCount: shakeCount
                )

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if isLoading {
                    ProgressView()
                } else {
                    NumberPadView(
                        onDigit: { digit in appendDigit(digit) },
                        onDelete: { deleteDigit() }
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Reset Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var currentInput: String {
        switch step {
        case .enterCode: return resetCode
        case .enterNew: return newPasscode
        case .confirmNew: return confirmPasscode
        }
    }

    private func appendDigit(_ digit: String) {
        guard currentInput.count < passcodeLength, !isLoading else { return }
        switch step {
        case .enterCode: resetCode += digit
        case .enterNew: newPasscode += digit
        case .confirmNew: confirmPasscode += digit
        }
        errorMessage = nil
        if currentInput.count == passcodeLength { handleComplete() }
    }

    private func deleteDigit() {
        guard !currentInput.isEmpty, !isLoading else { return }
        switch step {
        case .enterCode: resetCode.removeLast()
        case .enterNew: newPasscode.removeLast()
        case .confirmNew: confirmPasscode.removeLast()
        }
    }

    private func handleComplete() {
        switch step {
        case .enterCode:
            step = .enterNew

        case .enterNew:
            step = .confirmNew

        case .confirmNew:
            if confirmPasscode == newPasscode {
                submitReset()
            } else {
                newPasscode = ""
                confirmPasscode = ""
                triggerError("Passcodes don't match")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    step = .enterNew
                }
            }
        }
    }

    private func submitReset() {
        isLoading = true
        Task {
            do {
                try await passcodeService.resetPasscode(code: resetCode, newPasscode: newPasscode)
                passcodeService.unlockApp()
                dismiss()
            } catch {
                triggerError(error.localizedDescription)
                isLoading = false
            }
        }
    }

    private func triggerError(_ message: String) {
        errorMessage = message
        confirmPasscode = ""
        withAnimation { shakeCount += 1 }
    }
}
