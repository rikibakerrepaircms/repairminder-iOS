//
//  PasscodeLockView.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import SwiftUI

struct PasscodeLockView: View {
    @StateObject private var viewModel = PasscodeLockViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)

                Text("Enter Passcode")
                    .font(.title2)
                    .fontWeight(.semibold)

                PINDotsView(
                    enteredCount: viewModel.enteredDigits.count,
                    totalCount: viewModel.passcodeLength,
                    shakeCount: viewModel.shakeCount
                )

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                NumberPadView(
                    onDigit: { viewModel.appendDigit($0) },
                    onDelete: { viewModel.deleteDigit() }
                )

                if viewModel.canUseBiometric {
                    Button(action: { viewModel.authenticateWithBiometric() }) {
                        Image(systemName: viewModel.biometricIcon)
                            .font(.system(size: 36))
                            .foregroundStyle(Color.accentColor)
                    }
                    .disabled(viewModel.isAuthenticating)
                    .padding(.top, 4)
                }

                Button("Forgot Passcode?") {
                    viewModel.showForgotAlert = true
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
        }
        .alert("Forgot Passcode?", isPresented: $viewModel.showForgotAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Send Reset Email", role: .destructive) {
                viewModel.requestPasscodeReset()
            }
            Button("Logout", role: .destructive) {
                viewModel.forceLogout()
            }
        } message: {
            Text("We can send a reset code to your email, or you can logout and sign in again.")
        }
        .sheet(isPresented: $viewModel.showResetFlow) {
            ResetPasscodeView()
        }
        .task {
            viewModel.attemptBiometricOnAppear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.attemptBiometricOnAppear()
            }
        }
    }
}
