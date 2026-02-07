//
//  TwoFactorView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// View for entering 2FA verification code (email code, TOTP, or recovery code)
struct TwoFactorView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss

    /// Whether this is a magic link flow (vs password + 2FA)
    let useMagicLink: Bool

    @State private var code: String = ""
    @State private var isResending = false
    @State private var resendCooldown = 0

    @FocusState private var hiddenFieldFocused: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background image with overlay
            Image("login_background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            Color.black.opacity(0.5)
                .ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Image("login_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)

                            Text("Verification Code")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            VStack(spacing: 4) {
                                Text("Enter the 6-digit code sent to")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))

                                if let email = authManager.pendingEmail {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                }
                            }
                            .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)

                        // 6-digit code input boxes
                        ZStack {
                            // Single hidden TextField — sole keyboard input target
                            TextField("", text: $code)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .focused($hiddenFieldFocused)
                                .opacity(0.01)
                                .frame(width: 1, height: 1)
                                .onChange(of: code) { _, newValue in
                                    let digits = String(newValue.filter { $0.isNumber }.prefix(6))
                                    if digits != newValue {
                                        code = digits
                                    } else if digits.count == 6 && !authManager.isLoading {
                                        verifyCode()
                                    }
                                }

                            HStack(spacing: 8) {
                                ForEach(0..<6, id: \.self) { index in
                                    CodeDigitBox(
                                        digit: index < code.count ? String(code[code.index(code.startIndex, offsetBy: index)]) : "",
                                        isFocused: hiddenFieldFocused && index == min(code.count, 5)
                                    )
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { hiddenFieldFocused = true }
                        }
                        .padding(.horizontal, 24)

                        // Error message
                        if let error = authManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 24)
                        }

                        // Verify button
                        Button(action: verifyCode) {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Verify")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(code.count == 6 && !authManager.isLoading ? Color.blue : Color.blue.opacity(0.4))
                        .foregroundStyle(.white)
                        .contentShape(Rectangle())
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 24)
                        .disabled(code.count < 6 || authManager.isLoading)

                        // Resend code button
                        Button {
                            resendCode()
                        } label: {
                            if isResending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            } else if resendCooldown > 0 {
                                Text("Resend code in \(resendCooldown)s")
                            } else {
                                Text("Resend code")
                            }
                        }
                        .tint(.blue)
                        .disabled(isResending || resendCooldown > 0)

                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: 500)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }
        }
        .onAppear {
            hiddenFieldFocused = true
            startResendCooldown()
        }
        .onReceive(timer) { _ in
            if resendCooldown > 0 {
                resendCooldown -= 1
            }
        }
    }

    private func verifyCode() {
        guard code.count == 6 else { return }

        hiddenFieldFocused = false

        Task {
            do {
                if useMagicLink {
                    try await authManager.verifyMagicLinkCode(code)
                } else {
                    try await authManager.verify2FACode(code)
                }
                // Success - notify app state
                await appState.onStaffAuthenticated()
            } catch {
                // Error is handled by authManager.errorMessage
                code = ""
                hiddenFieldFocused = true
            }
        }
    }

    private func resendCode() {
        isResending = true

        Task {
            do {
                if useMagicLink {
                    if let email = authManager.pendingEmail {
                        try await authManager.requestMagicLink(email: email)
                    }
                } else {
                    try await authManager.request2FACode()
                }
                startResendCooldown()
            } catch {
                // Error is handled by authManager.errorMessage
            }
            isResending = false
        }
    }

    private func startResendCooldown() {
        resendCooldown = 60
    }
}

// MARK: - Code Digit Box

struct CodeDigitBox: View {
    let digit: String
    let isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? Color.blue : Color.white.opacity(0.3), lineWidth: isFocused ? 2 : 1)
                )

            Text(digit)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(width: 50, height: 56)
    }
}

#Preview {
    NavigationStack {
        TwoFactorView(useMagicLink: true)
    }
}
