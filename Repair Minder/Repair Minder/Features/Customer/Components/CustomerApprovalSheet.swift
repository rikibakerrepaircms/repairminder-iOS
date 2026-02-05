//
//  CustomerApprovalSheet.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Multi-step approval sheet for quote/offer approval or rejection
struct CustomerApprovalSheet: View {
    let order: CustomerOrderDetail
    @ObservedObject var viewModel: CustomerOrderDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: ApprovalStep = .review
    @State private var signatureType: CustomerSignatureView.SignatureType = .typed
    @State private var typedName: String = ""
    @State private var drawnSignature: UIImage?
    @State private var rejectionReason: String = ""
    @State private var showTerms: Bool = false

    // Bank details for buyback
    @State private var accountHolder: String = ""
    @State private var sortCode: String = ""
    @State private var accountNumber: String = ""

    enum ApprovalStep {
        case review
        case bankDetails  // Buyback only
        case signature
        case confirmReject
    }

    /// Whether any device is a buyback
    private var hasBuybackDevice: Bool {
        order.devices.contains { $0.isBuyback }
    }

    /// Whether all devices are buyback (no repair)
    private var isAllBuyback: Bool {
        order.devices.allSatisfy { $0.isBuyback }
    }

    /// Label for approve button based on workflow
    private var approveLabel: String {
        if isAllBuyback {
            return "Accept Offer"
        }
        return "Approve Quote"
    }

    /// Label for decline button based on workflow
    private var declineLabel: String {
        if isAllBuyback {
            return "Decline Offer"
        }
        return "Decline Quote"
    }

    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .review:
                    reviewStep
                case .bankDetails:
                    bankDetailsStep
                case .signature:
                    signatureStep
                case .confirmReject:
                    confirmRejectStep
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.approvalError != nil)) {
                Button("OK") {
                    viewModel.approvalError = nil
                }
            } message: {
                Text(viewModel.approvalError ?? "")
            }
            .onChange(of: viewModel.approvalSuccess) {
                if viewModel.approvalSuccess {
                    dismiss()
                }
            }
        }
    }

    private var navigationTitle: String {
        switch currentStep {
        case .review: return "Review"
        case .bankDetails: return "Bank Details"
        case .signature: return "Sign"
        case .confirmReject: return "Confirm Decline"
        }
    }

    // MARK: - Review Step

    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Quote/Offer Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text(isAllBuyback ? "Offer Summary" : "Quote Summary")
                        .font(.headline)

                    ForEach(order.items) { item in
                        HStack {
                            Text(item.description)
                                .font(.subheadline)
                            Spacer()
                            Text(formatCurrency(item.lineTotalIncVat))
                                .font(.subheadline)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(formatCurrency(order.totals.grandTotal))
                            .font(.headline)
                    }

                    if let paid = order.totals.amountPaid, paid > 0 {
                        HStack {
                            Text("Already Paid")
                                .foregroundStyle(.green)
                            Spacer()
                            Text("-\(formatCurrency(paid))")
                                .foregroundStyle(.green)
                        }
                        .font(.subheadline)

                        if let balance = order.totals.balanceDue {
                            HStack {
                                Text("Balance Due")
                                    .font(.headline)
                                Spacer()
                                Text(formatCurrency(balance))
                                    .font(.headline)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Terms and Conditions
                if let terms = order.company?.termsConditions, !terms.isEmpty {
                    Button {
                        showTerms.toggle()
                    } label: {
                        HStack {
                            Text("Terms & Conditions")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: showTerms ? "chevron.up" : "chevron.down")
                        }
                        .foregroundStyle(.primary)
                    }

                    if showTerms {
                        Text(terms)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        if hasBuybackDevice {
                            currentStep = .bankDetails
                        } else {
                            currentStep = .signature
                        }
                    } label: {
                        Text(approveLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        currentStep = .confirmReject
                    } label: {
                        Text(declineLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
                .padding(.top)
            }
            .padding()
        }
    }

    // MARK: - Bank Details Step (Buyback only)

    private var bankDetailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("We need your bank details to send your payment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account Holder Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Full name on account", text: $accountHolder)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sort Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("00-00-00", text: $sortCode)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .onChange(of: sortCode) {
                                sortCode = formatSortCode(sortCode)
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account Number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("8 digits", text: $accountNumber)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                    }
                }

                // Security Note
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.green)
                    Text("Your bank details are encrypted and only used to process your payment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        currentStep = .signature
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isBankDetailsValid)

                    Button {
                        currentStep = .review
                    } label: {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top)
            }
            .padding()
        }
    }

    private var isBankDetailsValid: Bool {
        !accountHolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        sortCode.filter { $0.isNumber }.count == 6 &&
        accountNumber.filter { $0.isNumber }.count == 8
    }

    private func formatSortCode(_ value: String) -> String {
        let numbers = value.filter { $0.isNumber }
        var result = ""
        for (index, char) in numbers.prefix(6).enumerated() {
            if index == 2 || index == 4 {
                result += "-"
            }
            result.append(char)
        }
        return result
    }

    // MARK: - Signature Step

    private var signatureStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Please sign below to confirm your approval.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Amount confirmation
                VStack(spacing: 8) {
                    Text("You are approving:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(order.totals.grandTotal))
                        .font(.title)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Signature View
                CustomerSignatureView(
                    signatureType: $signatureType,
                    typedName: $typedName,
                    drawnSignature: $drawnSignature
                )

                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.approveQuote(
                                signatureType: signatureType.rawValue,
                                signatureData: signatureData
                            )
                        }
                    } label: {
                        if viewModel.isSubmittingApproval {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Confirm Approval")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isSignatureValid || viewModel.isSubmittingApproval)

                    Button {
                        if hasBuybackDevice {
                            currentStep = .bankDetails
                        } else {
                            currentStep = .review
                        }
                    } label: {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isSubmittingApproval)
                }
                .padding(.top)
            }
            .padding()
        }
    }

    private var isSignatureValid: Bool {
        switch signatureType {
        case .typed:
            return !typedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .drawn:
            return drawnSignature != nil
        }
    }

    private var signatureData: String {
        switch signatureType {
        case .typed:
            return typedName.trimmingCharacters(in: .whitespacesAndNewlines)
        case .drawn:
            if let image = drawnSignature,
               let data = image.pngData() {
                return "data:image/png;base64," + data.base64EncodedString()
            }
            return ""
        }
    }

    // MARK: - Confirm Reject Step

    private var confirmRejectStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Warning
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Are you sure?")
                            .font(.headline)
                        Text("If you decline, you can contact us to discuss alternatives or arrange collection of your device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Reason (optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $rejectionReason)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Signature for rejection
                Text("Please sign to confirm your decision")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                CustomerSignatureView(
                    signatureType: $signatureType,
                    typedName: $typedName,
                    drawnSignature: $drawnSignature
                )

                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.rejectQuote(
                                reason: rejectionReason.isEmpty ? nil : rejectionReason,
                                signatureType: signatureType.rawValue,
                                signatureData: signatureData
                            )
                        }
                    } label: {
                        if viewModel.isSubmittingApproval {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Confirm Decline")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!isSignatureValid || viewModel.isSubmittingApproval)

                    Button {
                        currentStep = .review
                    } label: {
                        Text("Go Back")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isSubmittingApproval)
                }
                .padding(.top)
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = order.currencyCode
        return formatter.string(from: amount as NSDecimalNumber) ?? "£\(amount)"
    }
}

// MARK: - Preview

#Preview {
    Text("Preview requires CustomerOrderDetail")
}
