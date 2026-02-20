//
//  BuybackPayoutSheet.swift
//  Repair Minder
//

import SwiftUI

// MARK: - Bank Details

struct BankDetails {
    let accountHolder: String?
    let sortCode: String?
    let accountNumber: String?
}

// MARK: - Buyback Payout Sheet

struct BuybackPayoutSheet: View {
    let device: OrderDeviceSummary
    let payoutAmount: Double
    let bankDetails: BankDetails?
    let orderNumber: Int
    let onSave: (ManualPaymentRequest) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: PayoutMethod? = .bankTransfer
    @State private var paymentReference: String = ""
    @State private var cashNotes: String = ""
    @State private var additionalNotes: String = ""
    @State private var isSaving: Bool = false
    @State private var copiedField: String?
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Payout Method

    private enum PayoutMethod: String, CaseIterable, Identifiable {
        case bankTransfer = "bank_transfer"
        case cash

        var id: String { rawValue }

        var label: String {
            switch self {
            case .bankTransfer: return "Bank Transfer"
            case .cash: return "Cash"
            }
        }

        var icon: String {
            switch self {
            case .bankTransfer: return "building.columns"
            case .cash: return "banknote"
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        guard selectedMethod != nil else { return false }
        if selectedMethod == .bankTransfer {
            return !paymentReference.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    deviceInfoCard
                    paymentMethodPicker
                    if selectedMethod == .bankTransfer {
                        bankDetailsSection
                        paymentReferenceField
                        additionalNotesField
                    } else if selectedMethod == .cash {
                        cashNotesField
                    }
                }
                .padding()
            }
            .navigationTitle("Record Payout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await handleSave() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Record Payout")
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving || !isFormValid)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                // If no bank details, default to cash
                if bankDetails == nil ||
                    (bankDetails?.accountHolder == nil && bankDetails?.sortCode == nil && bankDetails?.accountNumber == nil) {
                    selectedMethod = .cash
                }
            }
        }
    }

    // MARK: - Device Info Card

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Device", systemImage: "iphone")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text(device.displayName ?? "Unknown Device")
                    .font(.headline)

                if let serial = device.serialNumber {
                    Label(serial, systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Payout Amount")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(CurrencyFormatter.format(payoutAmount))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }

                HStack {
                    Text("Order")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("#\(orderNumber)")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Payment Method Picker

    private var paymentMethodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment Method")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                ForEach(PayoutMethod.allCases) { method in
                    Button {
                        selectedMethod = method
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: method.icon)
                                .font(.title2)
                            Text(method.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .foregroundStyle(selectedMethod == method ? Color.accentColor : .primary)
                        .background(selectedMethod == method ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedMethod == method ? Color.accentColor : .clear, lineWidth: 2)
                        )
                        .overlay(alignment: .topTrailing) {
                            if selectedMethod == method {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white, Color.accentColor)
                                    .offset(x: -4, y: 4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Bank Details Section

    private var bankDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bank Details")
                .font(.subheadline)
                .fontWeight(.medium)

            if let details = bankDetails,
               details.accountHolder != nil || details.sortCode != nil || details.accountNumber != nil {
                VStack(spacing: 0) {
                    if let holder = details.accountHolder, !holder.isEmpty {
                        copyableField(label: "Account Holder", value: holder)
                    }
                    if let sortCode = details.sortCode, !sortCode.isEmpty {
                        copyableField(label: "Sort Code", value: sortCode)
                    }
                    if let accountNumber = details.accountNumber, !accountNumber.isEmpty {
                        copyableField(label: "Account Number", value: accountNumber)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("No bank details available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func copyableField(label: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = value
                copiedField = label
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if copiedField == label { copiedField = nil }
                }
            } label: {
                Image(systemName: copiedField == label ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(copiedField == label ? .green : .blue)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Payment Reference

    private var paymentReferenceField: some View {
        FormTextField(
            label: "Payment Reference",
            text: $paymentReference,
            placeholder: "e.g. Bank transaction ID",
            isRequired: true
        )
    }

    // MARK: - Additional Notes (Bank Transfer)

    private var additionalNotesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Additional Notes")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("Optional notes", text: $additionalNotes, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Cash Notes

    private var cashNotesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("e.g. Paid in cash at counter", text: $cashNotes, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Save

    private func handleSave() async {
        guard let method = selectedMethod else { return }
        isSaving = true

        var notes = ""
        if method == .bankTransfer {
            notes = "Ref: \(paymentReference)"
            let extra = additionalNotes.trimmingCharacters(in: .whitespaces)
            if !extra.isEmpty {
                notes += " - \(extra)"
            }
        } else {
            notes = cashNotes.trimmingCharacters(in: .whitespaces)
        }

        let request = ManualPaymentRequest(
            amount: payoutAmount,
            paymentMethod: method.rawValue,
            paymentDate: Self.isoDateFormatter.string(from: Date()),
            notes: notes.isEmpty ? nil : notes,
            deviceId: device.id,
            isDeposit: nil,
            isPayout: true
        )

        let success = await onSave(request)
        isSaving = false

        if success {
            dismiss()
        } else {
            errorMessage = "Failed to record payout. Please try again."
            showError = true
        }
    }
}
