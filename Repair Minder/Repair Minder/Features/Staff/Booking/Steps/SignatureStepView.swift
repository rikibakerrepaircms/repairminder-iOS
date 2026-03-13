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

            // Planned Services Summary (only if any device has line items)
            let devicesWithItems = viewModel.formData.devices.filter { !$0.lineItems.isEmpty }

            if !devicesWithItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Planned Services")
                        .font(.headline)

                    ForEach(devicesWithItems) { device in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(device.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            ForEach(device.lineItems) { item in
                                HStack {
                                    Text("• \(item.description)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(CurrencyFormatter.format(item.unitPrice))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 8)
                            }

                            // Subtotal per device
                            HStack {
                                Spacer()
                                Text("Device subtotal:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(CurrencyFormatter.format(device.lineItemSubtotal))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.leading, 8)
                        }
                        .padding()
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // Aftermarket consent (per device with aftermarket items)
            let aftermarketDeviceIndices = viewModel.formData.devices.indices.filter { i in
                viewModel.formData.devices[i].hasAftermarketItems
            }

            if !aftermarketDeviceIndices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(aftermarketDeviceIndices, id: \.self) { index in
                        let device = viewModel.formData.devices[index]

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 12) {
                                Toggle("", isOn: $viewModel.formData.devices[index].aftermarketConsent)
                                    .labelsHidden()
                                    .tint(.orange)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Aftermarket Parts — \(device.displayName)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text("This repair will use aftermarket parts not manufactured by Apple. By proceeding, I understand and accept the following risks:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• Battery performance may be reduced compared to an original component")
                                        Text("• Touchscreen responsiveness may be inconsistent or unreliable at times")
                                        Text("• Display colours may not appear fully accurate")
                                        Text("• Apple may restrict certain software features at their discretion in future updates")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                    Link(destination: URL(string: "https://mendmyi.com/repairs/premium-vs-aftermarket-iphone-screen")!) {
                                        HStack(spacing: 4) {
                                            Text("Learn more")
                                            Image(systemName: "arrow.up.right.square")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    }

                                    Text("I agree to the use of aftermarket parts and accept the risks outlined above.")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }

                            if !device.aftermarketConsent {
                                Label("Customer must acknowledge aftermarket parts to proceed.",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
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
            .background(Color.platformGray6)
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
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
