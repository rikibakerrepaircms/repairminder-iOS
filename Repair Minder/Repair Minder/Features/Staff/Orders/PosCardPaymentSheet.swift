//
//  PosCardPaymentSheet.swift
//  Repair Minder
//

import SwiftUI

struct PosCardPaymentSheet: View {
    let order: Order
    let balanceDue: Double
    let depositsEnabled: Bool
    let terminals: [PosTerminal]
    let paymentService: PaymentService
    let onSuccess: () async -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var state: PaymentState = .select
    @State private var paymentMode: PaymentMode = .terminal
    @State private var selectedTerminalId: String?
    @State private var selectedDeviceIds: Set<String> = []
    @State private var customAmountText: String = ""
    @State private var customerEmail: String = ""
    @State private var currentTransactionId: String?
    @State private var timeRemaining: Int = 120
    @State private var pollTask: Task<Void, Never>?
    @State private var isInitiating: Bool = false

    private let lastTerminalKey = "pos_last_terminal_id"
    private let pollInterval: TimeInterval = 2.0
    private let maxPollTime: Int = 120

    // MARK: - Payment State Machine

    private enum PaymentState {
        case select
        case processing
        case success(cardBrand: String?, lastFour: String?)
        case failed(reason: String?)
        case cancelled
        case timeout
        case linkCreated(url: String, emailSent: Bool)
    }

    private enum PaymentMode {
        case terminal
        case link
    }

    // MARK: - Computed Properties

    private var activeTerminals: [PosTerminal] {
        terminals.filter { $0.isActive == true }
    }

    private let repairCompleteStatuses: Set<String> = [
        "repaired_ready", "rejection_ready", "collected", "despatched"
    ]

    private func canTakePayment(_ device: OrderDeviceSummary) -> Bool {
        if device.workflowType == "buyback" { return true }
        if repairCompleteStatuses.contains(device.status) { return true }
        return depositsEnabled
    }

    private func isDepositOnly(_ device: OrderDeviceSummary) -> Bool {
        if device.workflowType == "buyback" { return false }
        return !repairCompleteStatuses.contains(device.status)
    }

    private var isDepositPayment: Bool {
        let selectedDevices = (order.devices ?? []).filter { selectedDeviceIds.contains($0.id) }
        return selectedDevices.contains { isDepositOnly($0) }
    }

    private var paymentAmountPounds: Double {
        if let custom = Double(customAmountText), custom > 0 {
            return custom
        }
        return selectedDeviceIds.isEmpty ? balanceDue : selectedDevicesTotal
    }

    private var paymentAmountPence: Int {
        Int(round(paymentAmountPounds * 100))
    }

    private var selectedDevicesTotal: Double {
        guard let devices = order.devices else { return balanceDue }
        let selected = devices.filter { selectedDeviceIds.contains($0.id) }
        guard !selected.isEmpty else { return balanceDue }

        return selected.reduce(0.0) { sum, device in
            let lineTotal = (order.items ?? [])
                .filter { $0.deviceId == device.id }
                .reduce(0.0) { $0 + $1.lineTotalIncVat }
            let paid = (device.deposits ?? 0) + (device.finalPaid ?? 0)
            return sum + max(0, lineTotal - paid)
        }
    }

    private var formattedTimeRemaining: String {
        let mins = timeRemaining / 60
        let secs = timeRemaining % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var canInitiate: Bool {
        guard paymentAmountPence > 0 else { return false }
        if paymentMode == .terminal {
            return selectedTerminalId != nil
        }
        return true
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .select:
                    selectView
                case .processing:
                    processingView
                case .success(let cardBrand, let lastFour):
                    successView(cardBrand: cardBrand, lastFour: lastFour)
                case .failed(let reason):
                    failedView(reason: reason)
                case .cancelled:
                    cancelledView
                case .timeout:
                    timeoutView
                case .linkCreated(let url, let emailSent):
                    linkCreatedView(url: url, emailSent: emailSent)
                }
            }
            .navigationTitle("Card Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .select = state {
                        Button("Cancel") { dismiss() }
                    } else if case .processing = state {
                        // Cancel button is in the processing view itself
                    } else {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(!isSelectState)
        }
        .onAppear {
            if activeTerminals.isEmpty {
                paymentMode = .link
            } else if activeTerminals.count == 1 {
                selectedTerminalId = activeTerminals[0].id
            } else if let last = UserDefaults.standard.string(forKey: lastTerminalKey),
                      activeTerminals.contains(where: { $0.id == last }) {
                selectedTerminalId = last
            }
            customerEmail = order.client?.email ?? ""
        }
        .onDisappear {
            stopPolling()
        }
    }

    private var isSelectState: Bool {
        if case .select = state { return true }
        return false
    }

    // MARK: - Select View

    private var selectView: some View {
        ScrollView {
            VStack(spacing: 20) {
                orderSummaryCard
                if !activeTerminals.isEmpty {
                    paymentModeToggle
                }
                if paymentMode == .terminal {
                    terminalPicker
                } else {
                    emailField
                }
                if let devices = order.devices, !devices.isEmpty {
                    deviceSelection(devices)
                }
                amountInput
                if isDepositPayment {
                    depositIndicator
                }
                initiateButton
            }
            .padding()
        }
    }

    private var orderSummaryCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Order \(order.formattedOrderNumber)")
                    .font(.headline)
                Spacer()
            }
            HStack {
                Text("Order Total")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(CurrencyFormatter.format(order.totals?.grandTotal ?? order.orderTotal ?? 0))
            }
            .font(.subheadline)
            if let totals = order.totals, totals.amountPaid > 0 {
                HStack {
                    Text("Already Paid")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(CurrencyFormatter.format(totals.amountPaid))
                }
                .font(.subheadline)
            }
            HStack {
                Text("Balance Due")
                    .fontWeight(.semibold)
                Spacer()
                Text(CurrencyFormatter.format(balanceDue))
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Payment Mode Toggle

    private var paymentModeToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment Mode")
                .font(.subheadline)
                .fontWeight(.medium)

            Picker("Mode", selection: $paymentMode) {
                Label("Terminal", systemImage: "creditcard.and.123")
                    .tag(PaymentMode.terminal)
                Label("Send Link", systemImage: "link")
                    .tag(PaymentMode.link)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Terminal Picker

    private var terminalPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Terminal")
                .font(.subheadline)
                .fontWeight(.medium)

            if activeTerminals.count == 1, let terminal = activeTerminals.first {
                terminalCard(terminal, isSelected: true)
            } else {
                ForEach(activeTerminals) { terminal in
                    Button {
                        selectedTerminalId = terminal.id
                    } label: {
                        terminalCard(terminal, isSelected: selectedTerminalId == terminal.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func terminalCard(_ terminal: PosTerminal, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: terminal.providerIcon)
                .font(.title2)
                .foregroundStyle(providerColor(terminal.provider))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(terminal.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(terminal.providerLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }

    private func providerColor(_ provider: String) -> Color {
        switch provider {
        case "revolut": return .purple
        case "square": return .blue
        case "sumup": return .teal
        case "dojo": return .orange
        default: return .gray
        }
    }

    // MARK: - Email Field

    private var emailField: some View {
        FormTextField(
            label: "Customer Email",
            text: $customerEmail,
            placeholder: "customer@example.com",
            keyboardType: .emailAddress,
            autocapitalization: .never
        )
    }

    // MARK: - Device Selection

    @ViewBuilder
    private func deviceSelection(_ devices: [OrderDeviceSummary]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Devices")
                .font(.subheadline)
                .fontWeight(.medium)

            ForEach(devices) { device in
                let eligible = canTakePayment(device)
                let depositOnly = isDepositOnly(device)

                Button {
                    if selectedDeviceIds.contains(device.id) {
                        selectedDeviceIds.remove(device.id)
                    } else {
                        selectedDeviceIds.insert(device.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedDeviceIds.contains(device.id) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(selectedDeviceIds.contains(device.id) ? Color.accentColor : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.displayName ?? device.deviceStatus.label)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            HStack(spacing: 6) {
                                Text(device.deviceStatus.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if depositOnly && eligible {
                                    Text("Deposit only")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                                if !eligible {
                                    Text("Not ready")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(eligible ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!eligible)
            }
        }
    }

    // MARK: - Amount Input

    private var amountInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            FormTextField(
                label: "Amount (£)",
                text: $customAmountText,
                placeholder: String(format: "%.2f", paymentAmountPounds),
                keyboardType: .decimalPad,
                autocapitalization: .never
            )

            if !customAmountText.isEmpty, let custom = Double(customAmountText), custom > balanceDue, balanceDue > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("This exceeds the outstanding balance")
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Deposit Indicator

    private var depositIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            Text("This will be recorded as a deposit")
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Initiate Button

    private var initiateButton: some View {
        Button {
            Task {
                if paymentMode == .terminal {
                    await initiateTerminalPayment()
                } else {
                    await createPaymentLink()
                }
            }
        } label: {
            HStack {
                if isInitiating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
                if paymentMode == .terminal {
                    Text("Pay \(CurrencyFormatter.format(paymentAmountPounds)) on Terminal")
                } else {
                    Text("Send Payment Link")
                }
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canInitiate && !isInitiating ? Color.accentColor : Color.gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canInitiate || isInitiating)
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .controlSize(.large)

            VStack(spacing: 8) {
                Text(timeRemaining > 100 ? "Waiting for card..." : "Processing payment...")
                    .font(.title3)
                    .fontWeight(.semibold)

                if let terminalId = selectedTerminalId,
                   let terminal = activeTerminals.first(where: { $0.id == terminalId }) {
                    Text("on \(terminal.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(formattedTimeRemaining)
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Button(role: .destructive) {
                Task { await cancelPayment() }
            } label: {
                Text("Cancel Payment")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Success View

    private func successView(cardBrand: String?, lastFour: String?) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Payment Successful!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(CurrencyFormatter.format(paymentAmountPounds))
                    .font(.title)
                    .fontWeight(.semibold)

                if let brand = cardBrand, let last4 = lastFour {
                    Text("\(brand) ending in \(last4)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    await onSuccess()
                    dismiss()
                }
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Failed View

    private func failedView(reason: String?) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("Payment Failed")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(reason ?? "The payment could not be processed. Please try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    resetToSelect()
                } label: {
                    Text("Try Again")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Cancelled View

    private var cancelledView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "xmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Payment Cancelled")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("The payment was cancelled.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                resetToSelect()
            } label: {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Timeout View

    private var timeoutView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Payment Timed Out")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("No response from the terminal. Please check the terminal and try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    resetToSelect()
                } label: {
                    Text("Try Again")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Link Created View

    @State private var linkCopied: Bool = false

    private func linkCreatedView(url: String, emailSent: Bool) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "link.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Payment Link Created")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(CurrencyFormatter.format(paymentAmountPounds))
                    .font(.title3)
                    .fontWeight(.semibold)

                if emailSent, let email = order.client?.email, !email.isEmpty {
                    Text("Email sent to \(email)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 12) {
                Text(url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    UIPasteboard.general.string = url
                    linkCopied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        linkCopied = false
                    }
                } label: {
                    Label(linkCopied ? "Copied!" : "Copy Link", systemImage: linkCopied ? "checkmark" : "doc.on.doc")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundStyle(linkCopied ? .green : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 40)

            Button {
                Task {
                    await onSuccess()
                    dismiss()
                }
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func initiateTerminalPayment() async {
        guard let terminalId = selectedTerminalId else { return }
        isInitiating = true

        UserDefaults.standard.set(terminalId, forKey: lastTerminalKey)

        let request = InitiateTerminalPaymentRequest(
            orderId: order.id,
            terminalId: terminalId,
            amount: paymentAmountPence,
            currency: "GBP",
            deviceIds: selectedDeviceIds.isEmpty ? nil : Array(selectedDeviceIds)
        )

        do {
            let response = try await paymentService.initiateTerminalPayment(request)
            currentTransactionId = response.transactionId
            isInitiating = false
            startPolling(transactionId: response.transactionId)
        } catch {
            isInitiating = false
            state = .failed(reason: error.localizedDescription)
        }
    }

    private func createPaymentLink() async {
        isInitiating = true

        let request = CreatePaymentLinkRequest(
            orderId: order.id,
            amount: paymentAmountPence,
            currency: "GBP",
            customerEmail: customerEmail.isEmpty ? nil : customerEmail,
            description: "Order \(order.formattedOrderNumber)",
            deviceIds: selectedDeviceIds.isEmpty ? nil : Array(selectedDeviceIds)
        )

        do {
            let response = try await paymentService.createPaymentLink(request)
            isInitiating = false
            state = .linkCreated(url: response.checkoutUrl, emailSent: response.emailSent == true)
        } catch {
            isInitiating = false
            state = .failed(reason: error.localizedDescription)
        }
    }

    private func startPolling(transactionId: String) {
        state = .processing
        timeRemaining = maxPollTime

        pollTask = Task {
            let timerTask = Task {
                while !Task.isCancelled && timeRemaining > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    if !Task.isCancelled {
                        timeRemaining -= 1
                    }
                }
            }

            while !Task.isCancelled {
                do {
                    let response = try await paymentService.pollPaymentStatus(transactionId: transactionId)

                    if response.status.isTerminal {
                        timerTask.cancel()
                        handleTerminalStatus(response)
                        return
                    }

                    try await Task.sleep(for: .seconds(pollInterval))
                } catch {
                    if Task.isCancelled { return }
                    try? await Task.sleep(for: .seconds(pollInterval))
                }

                if timeRemaining <= 0 {
                    timerTask.cancel()
                    state = .timeout
                    return
                }
            }
        }
    }

    private func handleTerminalStatus(_ response: PosTransactionPollResponse) {
        switch response.status {
        case .completed:
            state = .success(cardBrand: response.cardBrand, lastFour: response.cardLastFour)
        case .failed:
            state = .failed(reason: response.failureReason)
        case .cancelled:
            state = .cancelled
        case .timeout:
            state = .timeout
        default:
            break
        }
    }

    private func cancelPayment() async {
        stopPolling()
        if let transactionId = currentTransactionId {
            try? await paymentService.cancelTerminalPayment(transactionId: transactionId)
        }
        state = .cancelled
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func resetToSelect() {
        state = .select
        currentTransactionId = nil
        isInitiating = false
    }
}
