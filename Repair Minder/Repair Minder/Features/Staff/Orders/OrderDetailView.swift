//
//  OrderDetailView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

struct OrderDetailView: View {
    @StateObject private var viewModel: OrderDetailViewModel
    @State private var selectedClientId: String?
    @State private var showItemFormSheet = false
    @State private var editingItem: OrderItem?
    @State private var itemToDelete: OrderItem?
    @State private var showDeleteConfirmation = false
    @State private var showPaymentSheet = false
    @State private var showCardPaymentSheet = false
    @State private var showPayoutSheet = false
    @State private var payoutDevice: OrderDeviceSummary?
    @State private var deletingPaymentId: String?
    @State private var showDeletePaymentAlert = false
    @State private var selectedDeviceNav: DeviceNavTarget?
    @State private var selectedDocumentType: DocumentType?
    @State private var showDocumentSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    init(orderId: String) {
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(orderId: orderId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.order == nil {
                loadingView
            } else if let error = viewModel.error, viewModel.order == nil {
                errorView(error)
            } else if let order = viewModel.order {
                orderContent(order)
            }
        }
        .navigationTitle(viewModel.order?.formattedOrderNumber ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedClientId) { clientId in
            ClientDetailView(clientId: clientId)
        }
        .navigationDestination(item: $selectedDeviceNav) { target in
            DeviceDetailView(orderId: target.orderId, deviceId: target.id)
        }
        .task {
            await viewModel.loadOrder()
        }
    }

    // MARK: - Content

    private func orderContent(_ order: Order) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                headerCard(order)

                // Client section
                if let client = order.client {
                    clientSection(client)
                }

                // Devices section
                if let devices = order.devices, !devices.isEmpty {
                    devicesSection(devices, orderId: order.id)
                }

                // Items section
                if let items = order.items, !items.isEmpty {
                    itemsSection(items, order: order)
                } else if viewModel.isOrderEditable {
                    emptyItemsSection()
                }

                // Totals section
                if let totals = order.totals {
                    totalsSection(totals, paymentStatus: order.effectivePaymentStatus)
                }

                // Payment actions section
                if viewModel.isOrderEditable && viewModel.balanceDue > 0 {
                    paymentActionsSection(order)
                }

                // Payment links section
                if !viewModel.paymentLinks.isEmpty {
                    paymentLinksSection()
                }

                // Payments section
                if let payments = order.payments, !payments.isEmpty {
                    paymentsSection(payments)
                }

                // Refunds section
                if let refunds = order.refunds, !refunds.isEmpty {
                    refundsSection(refunds)
                }

                // Signatures section
                if let signatures = order.signatures, !signatures.isEmpty {
                    signaturesSection(signatures)
                }

                // Dates section
                if let dates = order.dates {
                    datesSection(dates)
                }

                // Notes section
                if let notes = order.notes, !notes.isEmpty {
                    notesSection(notes)
                }

                // Documents section
                documentsSection(order)
            }
            .padding()
            .frame(maxWidth: isRegularWidth ? 700 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showItemFormSheet) {
            if let order = viewModel.order {
                OrderItemFormSheet(
                    order: order,
                    editingItem: editingItem
                ) { request in
                    if let item = editingItem {
                        return await viewModel.updateItem(itemId: item.id, request: request)
                    } else {
                        return await viewModel.createItem(request)
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert("Delete Item", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    Task { _ = await viewModel.deleteItem(itemId: item.id) }
                }
            }
        } message: {
            if let item = itemToDelete {
                Text("Are you sure you want to delete \"\(item.description)\"? This cannot be undone.")
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.itemError != nil },
            set: { if !$0 { viewModel.clearItemError() } }
        )) {
            Button("OK") { }
        } message: {
            Text(viewModel.itemError ?? "")
        }
        // MARK: - Payment Sheets
        .sheet(isPresented: $showPaymentSheet) {
            if let order = viewModel.order {
                OrderPaymentFormSheet(
                    order: order,
                    balanceDue: viewModel.balanceDue,
                    depositsEnabled: viewModel.depositsEnabled,
                    onSave: { request in
                        await viewModel.recordPayment(request)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showCardPaymentSheet) {
            if let order = viewModel.order {
                PosCardPaymentSheet(
                    order: order,
                    balanceDue: viewModel.balanceDue,
                    depositsEnabled: viewModel.depositsEnabled,
                    terminals: viewModel.posTerminals,
                    paymentService: PaymentService(),
                    onSuccess: {
                        await viewModel.refresh()
                        await viewModel.loadPaymentLinks()
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showPayoutSheet) {
            if let order = viewModel.order, let device = payoutDevice {
                BuybackPayoutSheet(
                    device: device,
                    payoutAmount: device.payoutAmount ?? 0,
                    bankDetails: nil,
                    orderNumber: order.orderNumber,
                    onSave: { request in
                        await viewModel.recordPayment(request)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        // MARK: - Payment Alerts
        .alert("Delete Payment", isPresented: $showDeletePaymentAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let paymentId = deletingPaymentId {
                    Task { _ = await viewModel.deletePayment(paymentId: paymentId) }
                }
            }
        } message: {
            Text("Are you sure you want to delete this payment? This cannot be undone.")
        }
        .alert("Payment Error", isPresented: Binding(
            get: { viewModel.paymentError != nil },
            set: { if !$0 { viewModel.clearPaymentError() } }
        )) {
            Button("OK") { }
        } message: {
            Text(viewModel.paymentError ?? "")
        }
        // MARK: - Document Sheet
        .sheet(isPresented: $showDocumentSheet) {
            if let type = selectedDocumentType, let order = viewModel.order {
                DocumentPreviewSheet(orderId: order.id, orderNumber: order.orderNumber, documentType: type)
            }
        }
    }

    // MARK: - Header Card

    private func headerCard(_ order: Order) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.formattedOrderNumber)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let location = order.location {
                        Label(location.name, systemImage: "mappin")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                OrderStatusBadge(status: order.status)
            }

            Divider()

            HStack {
                if let intakeMethod = order.intakeMethod {
                    Label(intakeMethod.label, systemImage: intakeMethod.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let assignedUser = order.assignedUser {
                    Label(assignedUser.name, systemImage: "person")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Client Section

    private func clientSection(_ client: OrderClient) -> some View {
        SectionCard(title: "Client", icon: "person.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    selectedClientId = client.id
                } label: {
                    if isRegularWidth {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if let address = client.fullAddress {
                                    Label(address, systemImage: "location")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer(minLength: 24)

                            VStack(alignment: .trailing, spacing: 4) {
                                if let email = client.email {
                                    Label(email, systemImage: "envelope")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let phone = client.phone {
                                    Label(phone, systemImage: "phone")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if let email = client.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if let phone = client.phone {
                                    Text(phone)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                if !isRegularWidth, let address = client.fullAddress {
                    Divider()
                    Label(address, systemImage: "location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if client.emailSuppressed == true {
                    Divider()
                    Label("Email bounced", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Devices Section

    private func devicesSection(_ devices: [OrderDeviceSummary], orderId: String) -> some View {
        SectionCard(title: "Devices", icon: "iphone") {
            VStack(spacing: 0) {
                ForEach(devices) { device in
                    Button {
                        selectedDeviceNav = DeviceNavTarget(id: device.id, orderId: orderId)
                    } label: {
                        deviceRow(device)
                    }
                    .buttonStyle(.plain)

                    if device.id != devices.last?.id {
                        Divider().padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: OrderDeviceSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: device.workflowType == "buyback" ? "arrow.left.arrow.right" : "wrench.and.screwdriver")
                .font(.title3)
                .foregroundStyle(device.deviceStatus.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(device.displayName ?? "Unknown Device")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if let serial = device.serialNumber, !serial.isEmpty {
                    Text("S/N: \(serial)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(device.deviceStatus.color)
                            .frame(width: 6, height: 6)
                        Text(device.deviceStatus.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let auth = device.authorizationStatus, !auth.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(auth.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Items Section

    private func itemsSection(_ items: [OrderItem], order: Order) -> some View {
        SectionCard(title: "Items", icon: "list.bullet") {
            VStack(spacing: 0) {
                // "Add Item" button — top right, only when editable
                if viewModel.isOrderEditable {
                    HStack {
                        Spacer()
                        Button {
                            editingItem = nil
                            showItemFormSheet = true
                        } label: {
                            Label("Add Item", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.bottom, 8)
                }

                // Item rows
                ForEach(items) { item in
                    VStack(spacing: 0) {
                        HStack(alignment: .top) {
                            // Left column: description + type badge + auth status
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.description)
                                    .font(.subheadline)

                                HStack(spacing: 6) {
                                    if let type = item.itemType {
                                        Label(type.label, systemImage: type.icon)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let status = item.authorizationStatus {
                                        Text(status.capitalized)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(authorizationColor(status).opacity(0.15))
                                            .foregroundStyle(authorizationColor(status))
                                            .clipShape(Capsule())
                                    }
                                }
                            }

                            Spacer(minLength: 12)

                            // Right column: total + qty breakdown
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.formattedLineTotal)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("x\(item.quantity) @ \(item.formattedUnitPrice)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Context menu (edit/delete) — only when editable
                            if viewModel.isOrderEditable {
                                Menu {
                                    Button {
                                        editingItem = item
                                        showItemFormSheet = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32, height: 32)
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        if item.id != items.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func emptyItemsSection() -> some View {
        SectionCard(title: "Items", icon: "list.bullet") {
            VStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No items added yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    editingItem = nil
                    showItemFormSheet = true
                } label: {
                    Label("Add First Item", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func authorizationColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "approved": .green
        case "pending": .orange
        case "declined", "rejected": .red
        default: .secondary
        }
    }

    // MARK: - Totals Section

    private func totalsSection(_ totals: OrderTotals, paymentStatus: PaymentStatus) -> some View {
        SectionCard(title: "Totals", icon: "sum") {
            VStack(spacing: 8) {
                if isRegularWidth {
                    HStack(spacing: 24) {
                        totalRow("Subtotal", value: totals.formattedSubtotal)
                        totalRow("VAT", value: totals.formattedVatTotal)
                    }
                } else {
                    totalRow("Subtotal", value: totals.formattedSubtotal)
                    totalRow("VAT", value: totals.formattedVatTotal)
                }

                Divider()

                totalRow("Grand Total", value: totals.formattedGrandTotal, bold: true)
                totalRow("Amount Paid", value: totals.formattedAmountPaid, color: .green)

                if let refunded = totals.totalRefunded, refunded > 0 {
                    totalRow("Refunded", value: CurrencyFormatter.format(refunded), color: .orange)
                }

                Divider()

                HStack {
                    Text("Balance Due")
                        .fontWeight(.semibold)

                    Spacer()

                    PaymentStatusBadge(status: paymentStatus)

                    Text(totals.formattedBalanceDue)
                        .fontWeight(.bold)
                        .foregroundStyle(totals.balanceDue > 0 ? .red : .green)
                }
            }
        }
    }

    private func totalRow(_ label: String, value: String, bold: Bool = false, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .fontWeight(bold ? .semibold : .regular)

            Spacer()

            Text(value)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(color)
        }
        .font(.subheadline)
    }

    // MARK: - Payment Actions Section

    private func paymentActionsSection(_ order: Order) -> some View {
        SectionCard(title: "Payment Actions", icon: "plus.circle") {
            VStack(spacing: 10) {
                // Take Card Payment — only if POS terminals available
                if viewModel.hasActiveTerminals {
                    Button {
                        showCardPaymentSheet = true
                    } label: {
                        Label("Take Card Payment", systemImage: "creditcard.and.123")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }

                // Add Payment — always shown
                Button {
                    showPaymentSheet = true
                } label: {
                    Label("Add Payment", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                // Record Payout — only for first buyback device in ready_to_pay status
                if let device = order.devices?.first(where: {
                    $0.workflowType == "buyback" && $0.status == "ready_to_pay"
                }) {
                    Button {
                        payoutDevice = device
                        showPayoutSheet = true
                    } label: {
                        Label("Record Payout", systemImage: "arrow.up.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
            }
        }
    }

    // MARK: - Payment Links Section

    private func paymentLinksSection() -> some View {
        SectionCard(title: "Payment Links", icon: "link") {
            VStack(spacing: 8) {
                ForEach(viewModel.paymentLinks) { link in
                    VStack(spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(link.formattedAmount)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                if let date = link.formattedCreatedAt {
                                    Text(date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            paymentLinkStatusBadge(link.status)
                        }

                        // Actions for pending links
                        if link.status == .pending {
                            HStack(spacing: 12) {
                                Button {
                                    platformCopyToClipboard(link.checkoutUrl)
                                } label: {
                                    Label("Copy Link", systemImage: "doc.on.doc")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button(role: .destructive) {
                                    Task { await viewModel.cancelPaymentLink(linkId: link.id) }
                                } label: {
                                    Label("Cancel", systemImage: "xmark.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if link.id != viewModel.paymentLinks.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func paymentLinkStatusBadge(_ status: PaymentLinkStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .pending: return ("Pending", .orange)
            case .completed: return ("Completed", .green)
            case .failed: return ("Failed", .red)
            case .cancelled: return ("Cancelled", .gray)
            case .expired: return ("Expired", .gray)
            }
        }()

        return Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Payments Section

    private func paymentsSection(_ payments: [OrderPayment]) -> some View {
        SectionCard(title: "Payments", icon: "creditcard") {
            VStack(spacing: 8) {
                ForEach(payments) { payment in
                    paymentRow(payment)

                    if payment.id != payments.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func paymentRow(_ payment: OrderPayment) -> some View {
        let canDelete = payment.posTransactionId == nil && viewModel.isOrderEditable
        let amountColor: Color = payment.isFullyRefunded ? .secondary :
            payment.isPayoutPayment ? .orange :
            payment.amount < 0 ? .red : .green

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let method = payment.paymentMethod {
                        Image(systemName: method.icon)
                            .font(.caption)
                    }
                    Text(payment.paymentMethod?.label ?? "Payment")
                        .font(.subheadline)

                    if payment.isDepositPayment {
                        Text("Deposit")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    if payment.isPayoutPayment {
                        Text("Payout")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }

                    if payment.isFullyRefunded {
                        Text("REFUNDED")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }

                // Card brand/last4 + auth code for POS payments
                if let brand = payment.cardBrand, let last4 = payment.cardLastFour {
                    HStack(spacing: 4) {
                        Text("\(brand) •••• \(last4)")
                        if let authCode = payment.authCode, !authCode.isEmpty {
                            Text("(Auth: \(authCode))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                // Recorded by
                if let recordedBy = payment.recordedByName, !recordedBy.isEmpty {
                    Text("by \(recordedBy)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Device info
                if let deviceName = payment.deviceDisplayName {
                    Label(deviceName, systemImage: "iphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let date = payment.formattedDate {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Notes (1-line truncated)
                if let notes = payment.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Refund info
                if let refunded = payment.totalRefunded, refunded > 0, !payment.isFullyRefunded {
                    Text("Refunded: \(CurrencyFormatter.format(refunded))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Text(payment.formattedAmount)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(amountColor)
                .strikethrough(payment.isFullyRefunded, color: .secondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            if canDelete {
                Button(role: .destructive) {
                    deletingPaymentId = payment.id
                    showDeletePaymentAlert = true
                } label: {
                    Label("Delete Payment", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Refunds Section

    private func refundsSection(_ refunds: [OrderRefund]) -> some View {
        SectionCard(title: "Refunds", icon: "arrow.counterclockwise") {
            VStack(spacing: 8) {
                ForEach(refunds) { refund in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(refund.reason ?? "Refund")
                                .font(.subheadline)

                            if let date = refund.refundDate {
                                Text(date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text("-\(refund.formattedAmount)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Signatures Section

    private func signaturesSection(_ signatures: [OrderSignature]) -> some View {
        SectionCard(title: "Signatures", icon: "signature") {
            VStack(spacing: 8) {
                ForEach(signatures) { signature in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(signature.signatureType?.label ?? "Signature")
                                .font(.subheadline)

                            if let name = signature.typedName {
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if signature.hasSignature {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Dates Section

    private func datesSection(_ dates: OrderDates) -> some View {
        let entries = dateEntries(from: dates)
        return SectionCard(title: "Timeline", icon: "clock") {
            if isRegularWidth && entries.count > 2 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(entries.indices, id: \.self) { i in
                        dateRow(entries[i].label, date: entries[i].date, color: entries[i].color)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(entries.indices, id: \.self) { i in
                        dateRow(entries[i].label, date: entries[i].date, color: entries[i].color)
                    }
                }
            }
        }
    }

    private func dateEntries(from dates: OrderDates) -> [(label: String, date: String, color: Color)] {
        var entries: [(label: String, date: String, color: Color)] = []
        if let d = dates.createdAt { entries.append(("Created", d, .primary)) }
        if let d = dates.quoteSentAt { entries.append(("Quote Sent", d, .primary)) }
        if let d = dates.authorisedAt { entries.append(("Authorised", d, .primary)) }
        if let d = dates.rejectedAt { entries.append(("Rejected", d, .red)) }
        if let d = dates.serviceCompletedAt { entries.append(("Service Completed", d, .primary)) }
        if let d = dates.collectedAt { entries.append(("Collected", d, .green)) }
        if let d = dates.despatchedAt { entries.append(("Despatched", d, .green)) }
        return entries
    }

    private func dateRow(_ label: String, date: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            Text(DateFormatters.formatRelativeDate(date) ?? date)
                .font(.subheadline)
                .foregroundStyle(color)
        }
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: [OrderNote]) -> some View {
        SectionCard(title: "Notes", icon: "note.text") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(notes.indices, id: \.self) { index in
                    let note = notes[index]
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.body)
                            .font(.subheadline)

                        HStack {
                            if let createdBy = note.createdBy {
                                Text(createdBy)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let deviceName = note.deviceName {
                                Text("• \(deviceName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let createdAt = note.createdAt {
                                Text(DateFormatters.formatRelativeDate(createdAt) ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if index < notes.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Documents Section

    private func documentsSection(_ order: Order) -> some View {
        SectionCard(title: "Documents", icon: "doc.text") {
            VStack(spacing: 8) {
                documentButton(.bookingReceipt)
                documentButton(.invoice)

                if order.status == .collectedDespatched {
                    documentButton(.collectionReceipt)
                }
            }
        }
    }

    private func documentButton(_ type: DocumentType) -> some View {
        Button {
            selectedDocumentType = type
            showDocumentSheet = true
        } label: {
            HStack {
                Label(type.displayName, systemImage: type.icon)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading & Error

    private var loadingView: some View {
        LottieLoadingView(size: 100, message: "Loading order...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Retry") {
                Task {
                    await viewModel.loadOrder()
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Device Navigation Target

struct DeviceNavTarget: Identifiable, Hashable {
    let id: String      // deviceId
    let orderId: String
}

#Preview {
    NavigationStack {
        OrderDetailView(orderId: "test")
    }
}
