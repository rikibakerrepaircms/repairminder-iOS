//
//  VerifyPasscodeView.swift
//  Repair Minder
//

import SwiftUI

/// Prompts for the current app passcode to authorise a sensitive change
/// (e.g. turning off Passcode Lock) when biometrics aren't available.
struct VerifyPasscodeView: View {
    let reason: String
    let onVerified: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entered: String = ""
    @State private var errorMessage: String?
    @State private var shakeCount: Int = 0
    @State private var isChecking: Bool = false

    private let passcodeLength = 6
    private let passcodeService = PasscodeService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Text(reason)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                PINDotsView(
                    enteredCount: entered.count,
                    totalCount: passcodeLength,
                    shakeCount: shakeCount
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if isChecking {
                    ProgressView()
                } else {
                    NumberPadView(
                        onDigit: { appendDigit($0) },
                        onDelete: { deleteDigit() }
                    )
                }

                Spacer()
            }
            .frame(maxWidth: 350)
            .padding()
            .navigationTitle("Verify Passcode")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard entered.count < passcodeLength, !isChecking else { return }
        entered += digit
        errorMessage = nil
        if entered.count == passcodeLength { verify() }
    }

    private func deleteDigit() {
        guard !entered.isEmpty, !isChecking else { return }
        entered.removeLast()
    }

    private func verify() {
        isChecking = true
        Task {
            let ok = await passcodeService.verifyPasscodeAllowingServer(entered)
            isChecking = false
            if ok {
                onVerified()
                dismiss()
            } else {
                entered = ""
                errorMessage = "Incorrect passcode"
                withAnimation { shakeCount += 1 }
            }
        }
    }
}
