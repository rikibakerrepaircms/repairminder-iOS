//
//  SignatureStepView.swift
//  Repair Minder
//

import SwiftUI

struct SignatureStepView: View {
    @Bindable var viewModel: BookingViewModel
    @State private var showTermsSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Terms & Signature")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Please review the terms and provide a signature.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Terms Agreement
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    Toggle("", isOn: $viewModel.formData.termsAgreed)
                        .labelsHidden()
                        .tint(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("I agree to the terms and conditions")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Button {
                            showTermsSheet = true
                        } label: {
                            Text("View terms and conditions")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                // Marketing Consent
                HStack(spacing: 16) {
                    Toggle("", isOn: $viewModel.formData.marketingConsent)
                        .labelsHidden()
                        .tint(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Receive updates and promotions")
                            .font(.subheadline)

                        Text("Receive occasional emails about offers from \(viewModel.companyName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Divider()

            // Signature Section — reuses existing CustomerSignatureView
            VStack(alignment: .leading, spacing: 16) {
                Text("Signature")
                    .font(.headline)

                Text("Draw your signature below or type your name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                CustomerSignatureView(
                    signatureType: $viewModel.formData.signatureType,
                    typedName: $viewModel.formData.typedName,
                    drawnSignature: $viewModel.formData.drawnSignature
                )
            }

            // Validation Message
            if !viewModel.formData.hasValidSignature {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Please agree to terms and provide a signature or typed name.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsAndConditionsSheet(termsContent: viewModel.termsContent)
        }
        .task {
            if viewModel.termsContent.isEmpty {
                await viewModel.loadTermsAndConditions()
            }
        }
    }
}

// MARK: - Terms Sheet

struct TermsAndConditionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let termsContent: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if termsContent.isEmpty {
                        ProgressView("Loading terms...")
                    } else {
                        Text(termsContent)
                            .font(.body)
                    }
                }
                .padding()
            }
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        SignatureStepView(viewModel: BookingViewModel())
            .padding()
    }
}
