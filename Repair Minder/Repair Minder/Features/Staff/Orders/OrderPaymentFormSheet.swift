//
//  OrderPaymentFormSheet.swift
//  Repair Minder
//

import SwiftUI

struct OrderPaymentFormSheet: View {
    let order: Order
    let balanceDue: Double
    let depositsEnabled: Bool
    let onSave: (ManualPaymentRequest) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: PaymentMethod?
    @State private var amountText: String = ""
    @State private var paymentDate: Date = .now
    @State private var notes: String = ""
    @State private var invoiceNumber: String = ""
    @State private var selectedDeviceId: String?
    @State private var isDeposit: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init(order: Order, balanceDue: Double, depositsEnabled: Bool, onSave: @escaping (ManualPaymentRequest) async -> Bool) {
        self.order = order
        self.balanceDue = balanceDue
        self.depositsEnabled = depositsEnabled
        self.onSave = onSave
        _amountText = State(initialValue: balanceDue > 0 ? String(format: "%.2f", balanceDue) : "")
    }

    // MARK: - Validation

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: "£", with: "").trimmingCharacters(in: .whitespaces))
    }

    private var isOverpayment: Bool {
        guard let amount = parsedAmount else { return false }
        return amount > balanceDue && balanceDue > 0
    }

    private var isFormValid: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        guard selectedMethod != nil else { return false }
        if selectedMethod == .invoice && invoiceNumber.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return true
    }

    // MARK: - Deposit Visibility

    private let repairCompleteStatuses: Set<String> = [
        "repaired_ready", "rejection_ready", "collected", "despatched"
    ]

    private var showDepositToggle: Bool {
        guard depositsEnabled else { return false }
        guard let deviceId = selectedDeviceId,
              let device = order.devices?.first(where: { $0.id == deviceId }) else {
            return false
        }
        if device.workflowType == "buyback" { return false }
        return !repairCompleteStatuses.contains(device.status)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    paymentMethodPicker
                    amountSection
                    paymentDateSection
                    if let devices = order.devices, !devices.isEmpty {
                        devicePicker(devices)
                    }
                    if showDepositToggle {
                        depositToggle
                    }
                    if selectedMethod == .invoice {
                        invoiceNumberField
                    }
                    notesField
                    totalsPreview
                }
                .padding()
            }
            .navigationTitle("Record Payment")
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
                            Text("Record Payment")
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
        }
    }

    // MARK: - Payment Method Picker

    private var paymentMethodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment Method")
                .font(.subheadline)
                .fontWeight(.medium)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Button {
                        selectedMethod = method
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: method.icon)
                                .font(.title3)
                            Text(method.label)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity, minHeight: 70)
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

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            FormTextField(
                label: "Amount (£)",
                text: $amountText,
                placeholder: "0.00",
                keyboardType: .decimalPad,
                autocapitalization: .never,
                isRequired: true
            )

            Text("Balance due: \(CurrencyFormatter.format(balanceDue))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isOverpayment {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("This exceeds the outstanding balance")
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Payment Date

    private var paymentDateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Payment Date")
                .font(.subheadline)
                .fontWeight(.medium)

            DatePicker("", selection: $paymentDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Device Picker

    @ViewBuilder
    private func devicePicker(_ devices: [OrderDeviceSummary]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Apply to Device")
                .font(.subheadline)
                .fontWeight(.medium)

            Picker("Device", selection: $selectedDeviceId) {
                Text("Entire Order").tag(nil as String?)
                ForEach(devices) { device in
                    Text(deviceLabel(device)).tag(device.id as String?)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .onChange(of: selectedDeviceId) { _, _ in
            isDeposit = false
        }
    }

    private func deviceLabel(_ device: OrderDeviceSummary) -> String {
        let name = device.displayName ?? device.deviceStatus.label
        return "\(name) — \(device.deviceStatus.label)"
    }

    // MARK: - Deposit Toggle

    private var depositToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Mark as Deposit", isOn: $isDeposit)
                .tint(.orange)
            Text("Payment taken before repair is complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Invoice Number

    private var invoiceNumberField: some View {
        FormTextField(
            label: "Invoice Number",
            text: $invoiceNumber,
            placeholder: "e.g. INV-2024-001",
            isRequired: true
        )
    }

    // MARK: - Notes

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField(notesPlaceholder, text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var notesPlaceholder: String {
        switch selectedMethod {
        case .cash: return "e.g. Paid in cash at counter"
        case .bankTransfer: return "e.g. Transaction reference"
        case .invoice: return "Additional notes"
        default: return "Payment details (optional)"
        }
    }

    // MARK: - Totals Preview

    private var totalsPreview: some View {
        let orderTotal = order.totals?.grandTotal ?? order.orderTotal ?? 0
        let amountPaid = order.totals?.amountPaid ?? order.amountPaid ?? 0
        let thisPayment = parsedAmount ?? 0
        let newBalance = orderTotal - amountPaid - thisPayment

        return VStack(spacing: 6) {
            totalRow("Order Total", value: orderTotal)
            totalRow("Already Paid", value: amountPaid)
            totalRow("This Payment", value: thisPayment, color: .blue)
            Divider()
            HStack {
                Text("New Balance")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(CurrencyFormatter.format(newBalance))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(newBalance <= 0 ? .green : .primary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func totalRow(_ label: String, value: Double, color: Color = .secondary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(CurrencyFormatter.format(value))
                .font(.subheadline)
                .foregroundStyle(color)
        }
    }

    // MARK: - Save

    private func handleSave() async {
        guard let method = selectedMethod, let amount = parsedAmount else { return }
        isSaving = true

        var finalNotes = notes.trimmingCharacters(in: .whitespaces)
        if method == .invoice && !invoiceNumber.isEmpty {
            finalNotes = "Invoice #\(invoiceNumber)" + (finalNotes.isEmpty ? "" : " - \(finalNotes)")
        }

        let request = ManualPaymentRequest(
            amount: amount,
            paymentMethod: method.rawValue,
            paymentDate: Self.isoDateFormatter.string(from: paymentDate),
            notes: finalNotes.isEmpty ? nil : finalNotes,
            deviceId: selectedDeviceId,
            isDeposit: isDeposit ? true : nil,
            isPayout: nil
        )

        let success = await onSave(request)
        isSaving = false

        if success {
            dismiss()
        } else {
            errorMessage = "Failed to record payment. Please try again."
            showError = true
        }
    }
}
