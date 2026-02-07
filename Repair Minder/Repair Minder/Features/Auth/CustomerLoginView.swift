//
//  CustomerLoginView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Customer login view - magic link only (no password)
struct CustomerLoginView: View {
    @ObservedObject private var customerAuth = CustomerAuthManager.shared
    @ObservedObject private var appState = AppState.shared

    @State private var email = ""
    @State private var code: String = ""
    @State private var isResending = false
    @State private var resendCooldown = 0

    @FocusState private var focusedField: CustomerLoginField?
    @FocusState private var hiddenFieldFocused: Bool

    private enum CustomerLoginField {
        case email
    }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

                            // Content based on state
                            switch customerAuth.authState {
                            case .unauthenticated, .unknown:
                                emailEntryView
                            case .awaitingCode:
                                codeEntryView
                            case .companySelection:
                                CompanySelectionView()
                            case .authenticated:
                                // Should not show - handled by parent
                                EmptyView()
                            }

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
                        if customerAuth.authState == .awaitingCode || customerAuth.authState == .companySelection {
                            customerAuth.cancelLogin()
                        } else {
                            Task {
                                await appState.switchRole()
                            }
                        }
                    }
                }
            }
            .onReceive(timer) { _ in
                if resendCooldown > 0 {
                    resendCooldown -= 1
                }
            }
            .onChange(of: customerAuth.authState) { _, newState in
                if newState == .authenticated {
                    appState.onCustomerAuthenticated()
                }
            }
        }
    }

    // MARK: - Email Entry View

    private var emailEntryView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                LoginTextField(placeholder: "customer@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.go)
                    .onSubmit {
                        requestCode()
                    }
            }

            if let error = customerAuth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: requestCode) {
                if customerAuth.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Send Code")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isValidEmail && !customerAuth.isLoading ? Color.blue : Color.blue.opacity(0.4))
            .foregroundStyle(.white)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(!isValidEmail || customerAuth.isLoading)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Code Entry View

    private var codeEntryView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Enter the 6-digit code sent to")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                if let email = customerAuth.pendingEmail {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }
            .multilineTextAlignment(.center)

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
                        } else if digits.count == 6 && !customerAuth.isLoading {
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

            if let error = customerAuth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: verifyCode) {
                if customerAuth.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Verify")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(code.count == 6 && !customerAuth.isLoading ? Color.blue : Color.blue.opacity(0.4))
            .foregroundStyle(.white)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(code.count != 6 || customerAuth.isLoading)

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
        }
        .padding(.horizontal, 24)
        .onAppear {
            hiddenFieldFocused = true
            startResendCooldown()
        }
    }

    // MARK: - Helpers

    private var isValidEmail: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }

    private func requestCode() {
        guard isValidEmail else { return }

        focusedField = nil

        Task {
            do {
                try await customerAuth.requestMagicLink(email: email)
            } catch {
                // Error handled by customerAuth.errorMessage
            }
        }
    }

    private func verifyCode() {
        guard code.count == 6 else { return }

        hiddenFieldFocused = false

        Task {
            do {
                try await customerAuth.verifyCode(code)
            } catch {
                code = ""
                hiddenFieldFocused = true
            }
        }
    }

    private func resendCode() {
        guard let email = customerAuth.pendingEmail else { return }

        isResending = true

        Task {
            do {
                customerAuth.cancelLogin()
                self.email = email
                try await customerAuth.requestMagicLink(email: email)
                startResendCooldown()
            } catch {
                // Error handled
            }
            isResending = false
        }
    }

    private func startResendCooldown() {
        resendCooldown = 60
    }
}

#Preview {
    CustomerLoginView()
}
