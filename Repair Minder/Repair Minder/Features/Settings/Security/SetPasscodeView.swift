//
//  SetPasscodeView.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import SwiftUI

struct SetPasscodeView: View {
    enum Mode { case create, change }

    let mode: Mode
    let onComplete: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step
    @State private var currentInput: String = ""
    @State private var firstEntry: String = ""
    @State private var verifiedCurrentPasscode: String = ""
    @State private var errorMessage: String?
    @State private var shakeCount: Int = 0
    @State private var isLoading: Bool = false

    private let passcodeLength = 6
    private let passcodeService = PasscodeService.shared

    enum Step: String {
        case enterCurrent = "Enter current passcode"
        case enterNew = "Create a passcode"
        case confirmNew = "Confirm passcode"
    }

    init(mode: Mode, onComplete: @escaping (Bool) -> Void) {
        self.mode = mode
        self.onComplete = onComplete
        _step = State(initialValue: mode == .change ? .enterCurrent : .enterNew)
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
                        onDigit: appendDigit,
                        onDelete: deleteDigit
                    )
                }

                Spacer()
            }
            .frame(maxWidth: 350)
            .padding()
            .navigationTitle(mode == .create ? "Set Passcode" : "Change Passcode")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(false)
                        dismiss()
                    }
                }
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard currentInput.count < passcodeLength, !isLoading else { return }
        currentInput += digit
        errorMessage = nil
        if currentInput.count == passcodeLength {
            handleCompleteEntry()
        }
    }

    private func deleteDigit() {
        guard !currentInput.isEmpty, !isLoading else { return }
        currentInput.removeLast()
    }

    private func handleCompleteEntry() {
        switch step {
        case .enterCurrent:
            if passcodeService.verifyPasscode(currentInput) {
                verifiedCurrentPasscode = currentInput
                currentInput = ""
                step = .enterNew
            } else {
                triggerError("Incorrect passcode")
            }

        case .enterNew:
            firstEntry = currentInput
            currentInput = ""
            step = .confirmNew

        case .confirmNew:
            if currentInput == firstEntry {
                savePasscode()
            } else {
                firstEntry = ""
                triggerError("Passcodes don't match. Try again.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    step = .enterNew
                }
            }
        }
    }

    private func savePasscode() {
        isLoading = true
        Task {
            do {
                if mode == .create {
                    try await passcodeService.setPasscode(currentInput)
                } else {
                    try await passcodeService.changePasscode(
                        current: verifiedCurrentPasscode,
                        new: currentInput
                    )
                }
                onComplete(true)
                dismiss()
            } catch {
                triggerError(error.localizedDescription)
                isLoading = false
            }
        }
    }

    private func triggerError(_ message: String) {
        errorMessage = message
        currentInput = ""
        withAnimation { shakeCount += 1 }
    }
}
