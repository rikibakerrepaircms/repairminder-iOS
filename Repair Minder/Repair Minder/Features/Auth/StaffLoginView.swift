//
//  StaffLoginView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Staff login view with email/password form and magic link option
struct StaffLoginView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared

    @State private var email = ""
    @State private var password = ""
    @State private var showMagicLink = false
    @State private var showTwoFactor = false
    @State private var useMagicLink = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
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
                        VStack(spacing: 24) {
                            Spacer()
                                .frame(height: 60)

                            // Header
                            Image("login_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)

                            // Login form
                            VStack(spacing: 16) {
                                // Email field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)

                                    LoginTextField(placeholder: "staff@example.com", text: $email)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .email)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            focusedField = .password
                                        }
                                }

                                // Password field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Password")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)

                                    LoginTextField(placeholder: "Enter your password", text: $password, isSecure: true)
                                        .textContentType(.password)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                        .onSubmit {
                                            loginWithPassword()
                                        }
                                }

                                // Error message
                                if let error = authManager.errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                // Login button
                                Button(action: loginWithPassword) {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(isFormValid && !authManager.isLoading ? Color.blue : Color.blue.opacity(0.4))
                                .foregroundStyle(.white)
                                .contentShape(Rectangle())
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .disabled(!isFormValid || authManager.isLoading)
                            }
                            .padding(.horizontal, 24)

                            // Divider with "or"
                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)

                                Text("or")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))

                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.horizontal, 24)

                            // Magic link button
                            Button(action: requestMagicLink) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Sign in with Magic Link")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isValidEmail && !authManager.isLoading ? Color.blue : Color.blue.opacity(0.4))
                            .foregroundStyle(.white)
                            .contentShape(Rectangle())
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 24)
                            .disabled(!isValidEmail || authManager.isLoading)

                            Spacer(minLength: 40)
                        }
                        .frame(maxWidth: 500)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height)
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        Task {
                            await appState.switchRole()
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showTwoFactor) {
                TwoFactorView(useMagicLink: useMagicLink)
            }
            .onAppear {
                // Clear any previous state
                email = ""
                password = ""
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    private var isValidEmail: Bool {
        !email.isEmpty && email.contains("@")
    }

    private func loginWithPassword() {
        guard isFormValid else { return }

        focusedField = nil
        useMagicLink = false

        Task {
            do {
                try await authManager.login(email: email, password: password)
                // If successful, 2FA code was sent - show 2FA screen
                showTwoFactor = true
            } catch {
                // Error is handled by authManager.errorMessage
            }
        }
    }

    private func requestMagicLink() {
        guard isValidEmail else { return }

        focusedField = nil
        useMagicLink = true

        Task {
            do {
                try await authManager.requestMagicLink(email: email)
                showTwoFactor = true
            } catch {
                // Error is handled by authManager.errorMessage
            }
        }
    }
}

// MARK: - Login Field Style

extension View {
    func loginFieldStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .tint(.blue)
            .foregroundStyle(.blue)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Login Text Field

struct LoginTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.gray)
            }

            if isSecure {
                SecureField("", text: $text)
                    .foregroundStyle(.gray)
            } else {
                TextField("", text: $text)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    StaffLoginView()
}
