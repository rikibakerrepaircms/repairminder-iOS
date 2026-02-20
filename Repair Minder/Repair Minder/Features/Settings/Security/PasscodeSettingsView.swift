//
//  PasscodeSettingsView.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import SwiftUI

struct PasscodeSettingsView: View {
    @StateObject private var viewModel = PasscodeSettingsViewModel()
    @ObservedObject private var passcodeService = PasscodeService.shared

    var body: some View {
        List {
            // Passcode management
            Section("Passcode") {
                Toggle(isOn: Binding(
                    get: { passcodeService.passcodeEnabled },
                    set: { newValue in viewModel.toggleEnabled(newValue) }
                )) {
                    Label("Passcode Lock", systemImage: "lock.fill")
                }

                if passcodeService.passcodeEnabled {
                    Button("Change Passcode") {
                        viewModel.showChangePasscode = true
                    }
                }

                Button("Reset via Email") {
                    viewModel.showResetConfirmation = true
                }
            }

            // Biometric
            if passcodeService.isBiometricAvailable {
                Section {
                    Toggle(isOn: Binding(
                        get: { passcodeService.isBiometricEnabled },
                        set: { passcodeService.setBiometric(enabled: $0) }
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(passcodeService.biometricType.displayName)
                                Text("Unlock with \(passcodeService.biometricType.displayName) instead of passcode")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: passcodeService.biometricType.systemImage)
                        }
                    }
                }
            }

            // Timeout
            Section {
                Picker(selection: $viewModel.selectedTimeout) {
                    ForEach(viewModel.timeoutOptions, id: \.minutes) { option in
                        Text(option.label).tag(option.minutes)
                    }
                } label: {
                    Label("Require Passcode", systemImage: "timer")
                }
                .onChange(of: viewModel.selectedTimeout) { _, newValue in
                    viewModel.updateTimeout(newValue)
                }
            } footer: {
                Text("How long the app can be in the background before requiring the passcode again.")
            }
        }
        .navigationTitle("Security")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $viewModel.showChangePasscode) {
            SetPasscodeView(mode: .change) { _ in }
                .interactiveDismissDisabled()
        }
        .alert("Reset Passcode", isPresented: $viewModel.showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Send Reset Email") {
                viewModel.requestReset()
            }
        } message: {
            Text("We'll send a reset code to your registered email address.")
        }
        .sheet(isPresented: $viewModel.showResetFlow) {
            ResetPasscodeView()
                .interactiveDismissDisabled()
        }
        .alert("Disable Passcode Lock?", isPresented: $viewModel.showDisableConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Disable", role: .destructive) {
                viewModel.confirmDisable()
            }
        } message: {
            Text("Your passcode will be kept but the lock screen will no longer appear.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
