//
//  MagicLinkCodeView.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import SwiftUI

struct MagicLinkCodeView: View {
    @Bindable var viewModel: LoginViewModel
    @FocusState private var isCodeFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)

                Text("Check Your Email")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("We sent a 6-digit code to your email.\nEnter it below to sign in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Code entry field
                TextField("000000", text: $viewModel.verificationCode)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title.monospaced())
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 60)
                    .focused($isCodeFocused)
                    .onChange(of: viewModel.verificationCode) { _, newValue in
                        // Only allow digits
                        let filtered = newValue.filter(\.isNumber)
                        if filtered != newValue {
                            viewModel.verificationCode = filtered
                        }
                        // Limit to 6 digits
                        if filtered.count > 6 {
                            viewModel.verificationCode = String(filtered.prefix(6))
                        }
                        // Auto-submit when 6 digits entered
                        if viewModel.verificationCode.count == 6 {
                            Task { await viewModel.verifyCode() }
                        }
                    }

                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await viewModel.verifyCode() }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Verify")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isCodeValid || viewModel.isLoading)
                .padding(.horizontal)

                Button {
                    Task { await viewModel.resendCode() }
                } label: {
                    Text("Resend Code")
                        .font(.subheadline)
                }
                .disabled(viewModel.isLoading)

                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelCodeEntry()
                        dismiss()
                    }
                }
            }
            .onAppear {
                isCodeFocused = true
            }
            .interactiveDismissDisabled(viewModel.isLoading)
        }
    }
}

#Preview {
    MagicLinkCodeView(viewModel: LoginViewModel())
}
