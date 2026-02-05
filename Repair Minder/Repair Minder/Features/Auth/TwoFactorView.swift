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

    @State private var codeDigits: [String] = Array(repeating: "", count: 6)
    @State private var hiddenCode: String = "" // For auto-fill
    @State private var isResending = false
    @State private var resendCooldown = 0

    @FocusState private var focusedIndex: Int?
    @FocusState private var hiddenFieldFocused: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var code: String {
        codeDigits.joined()
    }

    private var nextEmptyIndex: Int {
        codeDigits.firstIndex(where: { $0.isEmpty }) ?? 5
    }

    var body: some View {
        ZStack {
            // Background image with overlay
            Image("login_background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            Color.black.opacity(0.5)
                .ignoresSafeArea()

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
                        // Hidden TextField for auto-fill support
                        TextField("", text: $hiddenCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($hiddenFieldFocused)
                            .opacity(0.01) // Nearly invisible but still functional
                            .frame(width: 1, height: 1)
                            .onChange(of: hiddenCode) { _, newValue in
                                handleAutoFill(newValue)
                            }

                        HStack(spacing: 8) {
                            ForEach(0..<6, id: \.self) { index in
                                CodeDigitBox(
                                    digit: $codeDigits[index],
                                    isFocused: focusedIndex == index || (hiddenFieldFocused && index == nextEmptyIndex),
                                    onTap: {
                                        // Focus the hidden field for auto-fill, but track which box visually
                                        hiddenFieldFocused = true
                                        focusedIndex = index
                                    },
                                    onDigitEntered: { digit in
                                        handleDigitEntry(digit, at: index)
                                    },
                                    onBackspace: {
                                        handleBackspace(at: index)
                                    }
                                )
                                .focused($focusedIndex, equals: index)
                            }
                        }
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
            // Focus hidden field for auto-fill support
            hiddenFieldFocused = true
            focusedIndex = 0
            startResendCooldown()
        }
        .onReceive(timer) { _ in
            if resendCooldown > 0 {
                resendCooldown -= 1
            }
        }
    }

    private func handleAutoFill(_ value: String) {
        // Filter to only digits
        let digits = value.filter { $0.isNumber }

        // If we got a full 6-digit code (auto-fill), distribute it
        if digits.count >= 6 {
            let codeArray = Array(digits.prefix(6))
            for (index, char) in codeArray.enumerated() {
                codeDigits[index] = String(char)
            }
            // Clear hidden field and dismiss keyboard
            hiddenCode = ""
            hiddenFieldFocused = false
            focusedIndex = nil

            // Auto verify
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if code.count == 6 {
                    verifyCode()
                }
            }
        } else if digits.count == 1 {
            // Single digit entered - put it in the next empty box
            let index = nextEmptyIndex
            codeDigits[index] = digits
            hiddenCode = "" // Clear for next input

            if index < 5 {
                focusedIndex = index + 1
            } else {
                // Last digit - auto verify
                hiddenFieldFocused = false
                focusedIndex = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if code.count == 6 {
                        verifyCode()
                    }
                }
            }
        }
    }

    private func handleDigitEntry(_ digit: String, at index: Int) {
        // Only accept single digit
        if let char = digit.last, char.isNumber {
            codeDigits[index] = String(char)

            // Move to next field
            if index < 5 {
                focusedIndex = index + 1
            } else {
                // Last digit entered - auto verify
                focusedIndex = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if code.count == 6 {
                        verifyCode()
                    }
                }
            }
        }
    }

    private func handleBackspace(at index: Int) {
        if codeDigits[index].isEmpty && index > 0 {
            // Move to previous field
            focusedIndex = index - 1
            codeDigits[index - 1] = ""
        } else {
            codeDigits[index] = ""
        }
    }

    private func verifyCode() {
        guard code.count == 6 else { return }

        focusedIndex = nil

        Task {
            do {
                if useMagicLink {
                    try await authManager.verifyMagicLinkCode(code)
                } else {
                    try await authManager.verify2FACode(code)
                }
                // Success - notify app state
                appState.onStaffAuthenticated()
            } catch {
                // Error is handled by authManager.errorMessage
                codeDigits = Array(repeating: "", count: 6)
                focusedIndex = 0
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
    @Binding var digit: String
    let isFocused: Bool
    let onTap: () -> Void
    let onDigitEntered: (String) -> Void
    let onBackspace: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? Color.blue : Color.white.opacity(0.3), lineWidth: isFocused ? 2 : 1)
                )

            TextField("", text: $digit)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .onChange(of: digit) { _, newValue in
                    if !newValue.isEmpty {
                        onDigitEntered(newValue)
                    }
                }
                .onKeyPress(.delete) {
                    onBackspace()
                    return .handled
                }
        }
        .frame(width: 50, height: 56)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    NavigationStack {
        TwoFactorView(useMagicLink: true)
    }
}
