//
//  CustomerLoginView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct CustomerLoginView: View {
    @Environment(CustomerAuthManager.self) private var authManager
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var showVerification = false
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Logo and title
                VStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    Text("Track Your Repair")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Enter your email to view your repair orders")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)

                if showVerification {
                    verificationCodeView
                } else {
                    emailEntryView
                }

                Spacer()
            }
            .padding(.horizontal)
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    // MARK: - Email Entry View

    private var emailEntryView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($isEmailFocused)
            }

            if let error = authManager.error {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }

            Button {
                Task {
                    let success = await authManager.requestCode(email: email)
                    if success {
                        showVerification = true
                        isCodeFocused = true
                    }
                }
            } label: {
                if authManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!email.isValidEmail || authManager.isLoading)
        }
    }

    // MARK: - Verification Code View

    private var verificationCodeView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Check your email")
                    .font(.headline)

                Text("We sent a verification code to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(email)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Verification Code")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("Enter 6-digit code", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.title2.monospaced())
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($isCodeFocused)
                    .onChange(of: verificationCode) { _, newValue in
                        // Limit to 6 digits
                        if newValue.count > 6 {
                            verificationCode = String(newValue.prefix(6))
                        }
                        // Auto-submit when 6 digits entered
                        if verificationCode.count == 6 {
                            Task {
                                await authManager.verifyCode(email: email, code: verificationCode)
                            }
                        }
                    }
            }

            if let error = authManager.error {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }

            Button {
                Task {
                    await authManager.verifyCode(email: email, code: verificationCode)
                }
            } label: {
                if authManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Verify")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(verificationCode.count < 6 || authManager.isLoading)

            Button("Use a different email") {
                showVerification = false
                verificationCode = ""
                isEmailFocused = true
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    CustomerLoginView()
        .environment(CustomerAuthManager())
}
