//
//  LoginView.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import SwiftUI

struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @FocusState private var isEmailFocused: Bool
    @Environment(\.brandColors) private var colors

    private let brand = BrandConfiguration.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo/Header
                    VStack(spacing: 8) {
                        BrandLogo(size: .large)

                        Text(brand.displayName)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Sign in to continue")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)

                    // Login Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isEmailFocused)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        if let error = viewModel.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task {
                                await viewModel.sendCode()
                            }
                        } label: {
                            Group {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send Code")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(colors.primary)
                        .disabled(!viewModel.isEmailValid || viewModel.isLoading)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
            .onSubmit {
                Task { await viewModel.sendCode() }
            }
            .sheet(isPresented: $viewModel.showCodeEntry) {
                MagicLinkCodeView(viewModel: viewModel)
            }
            .onAppear {
                isEmailFocused = true
            }
        }
    }
}

#Preview {
    LoginView()
}
