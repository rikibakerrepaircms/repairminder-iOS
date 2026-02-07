//
//  MagicLinkView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// View for requesting a magic link code via email
struct MagicLinkView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    /// Whether this is for staff (vs customer)
    let isStaff: Bool

    /// Initial email to pre-fill (from parent view)
    let initialEmail: String

    /// Callback when code is requested successfully
    let onCodeRequested: () -> Void

    @State private var email = ""
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Image("repairminder_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)

                            Text("Magic Link Login")
                                .font(.title)
                                .fontWeight(.bold)

                            Text("Enter your email and we'll send you\na code to sign in")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)

                        // Email input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            TextField("staff@example.com", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($isEmailFocused)
                                .submitLabel(.go)
                                .onSubmit {
                                    requestMagicLink()
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

                        // Request button
                        Button(action: requestMagicLink) {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Send Code")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !initialEmail.isEmpty {
                    email = initialEmail
                }
                isEmailFocused = true
            }
        }
    }

    private var isValidEmail: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }

    private func requestMagicLink() {
        guard isValidEmail else { return }

        isEmailFocused = false

        Task {
            do {
                try await authManager.requestMagicLink(email: email)
                // Success - notify parent to show code entry
                onCodeRequested()
            } catch {
                // Error is handled by authManager.errorMessage
            }
        }
    }
}

#Preview {
    MagicLinkView(isStaff: true, initialEmail: "") {
        #if DEBUG
        print("Code requested")
        #endif
    }
}
