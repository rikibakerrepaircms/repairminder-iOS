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
    @State private var dueDateDevice: OrderDeviceSummary?
    @State private var deviceToDelete: OrderDeviceSummary?
    @State private var showDeleteDeviceConfirmation = false
    @State private var deletingPaymentId: String?
    @State private var showDeletePaymentAlert = false
    @State private var selectedDeviceNav: DeviceNavTarget?
    @State private var selectedDocumentType: DocumentType?
    @State private var showDocumentSheet = false
    @State private var showAuthorizeSheet = false
    @State private var showDespatchSheet = false
    @State private var showCollectSheet = false
    @State private var showAddNoteSheet = false
    @State private var showDiscountSheet = false
    @State private var showReplySheet = false
    @State private var showResolveConfirmation = false
    @State private var refundTarget: OrderPayment?
    @State private var refundToDelete: OrderRefund?
    @State private var showDeleteRefundAlert = false
    @State private var showPurchaseOrderSheet = false
    @State private var showBillingGroupSheet = false
    @State private var showRecreateConfirmation = false
    @State private var showRecreateSheet = false
    @State private var recreateSuccessMessage: String?
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
                    totalsSection(totals, order: order)
                }

                // Close-out actions section
                closeOutActionsSection(order)

                // Admin section (purchase order, billing group, recreate)
                adminSection(order)

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

                // Customer / ticket conversation section
                if order.ticketId != nil {
                    customerSection(order)
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
                    initialBankDetails: nil,
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
        .alert("Delete Refund", isPresented: $showDeleteRefundAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let refund = refundToDelete {
                    Task { _ = await viewModel.deleteRefund(refundId: refund.id) }
                }
            }
        } message: {
            Text("Are you sure you want to delete this refund? This cannot be undone.")
        }
        // MARK: - Document Sheet
        .sheet(isPresented: $showDocumentSheet) {
            if let type = selectedDocumentType, let order = viewModel.order {
                DocumentPreviewSheet(
                    orderId: order.id,
                    orderNumber: order.orderNumber,
                    documentType: type,
                    // Log the handover on the ticket so there's a record even if
                    // the customer loses the copy we AirDropped them. Only the
                    // booking receipt matters here — it's the intake evidence.
                    onShared: type == .bookingReceipt ? { logBookingReceiptShared(order) } : nil
                )
            }
        }
        // MARK: - Close-out Sheets
        .sheet(isPresented: $showAuthorizeSheet) {
            AuthorizeOrderSheet { req in (await viewModel.authorize(req)) ? nil : (viewModel.actionError ?? "Could not authorize.") }
        }
        .sheet(isPresented: $showDespatchSheet) {
            DespatchOrderSheet { req in (await viewModel.despatch(req)) ? nil : (viewModel.actionError ?? "Could not despatch.") }
        }
        .sheet(isPresented: $showCollectSheet) {
            CollectOrderSheet { req in (await viewModel.collect(req)) ? nil : (viewModel.actionError ?? "Could not record collection.") }
        }
        .sheet(isPresented: $showAddNoteSheet) {
            AddOrderNoteSheet { req in (await viewModel.addNote(req)) ? nil : (viewModel.actionError ?? "Could not add note.") }
        }
        .sheet(isPresented: $showDiscountSheet) {
            if let order = viewModel.order {
                OrderDiscountSheet(order: order) { req in
                    (await viewModel.setGlobalDiscount(req)) ? nil : (viewModel.actionError ?? "Could not update discount.")
                }
            }
        }
        .sheet(isPresented: $showReplySheet) {
            ReplyToCustomerSheet(smsAvailable: viewModel.order?.client?.phone != nil) { plainText, sendSms in
                (await viewModel.replyToCustomer(plainText: plainText, sendSms: sendSms)) ? nil : (viewModel.actionError ?? "Could not send reply.")
            }
        }
        .confirmationDialog(
            "Resolve Ticket",
            isPresented: $showResolveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Resolve") {
                Task { _ = await viewModel.resolveTicket() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Mark this customer's ticket as resolved?")
        }
        .sheet(item: $refundTarget) { payment in
            RefundPaymentSheet(payment: payment) { req in (await viewModel.createRefund(req)) ? nil : (viewModel.actionError ?? "Refund failed.") }
        }
        // MARK: - Admin Sheets (Package G)
        .sheet(isPresented: $showPurchaseOrderSheet) {
            if let order = viewModel.order {
                PurchaseOrderSheet(order: order) { req in
                    (await viewModel.updatePurchaseOrder(req)) ? nil : (viewModel.actionError ?? "Could not update purchase order.")
                }
            }
        }
        .sheet(isPresented: $showBillingGroupSheet) {
            if let order = viewModel.order {
                BillingGroupSheet(
                    order: order,
                    fetchGroups: { await viewModel.fetchClientGroups() }
                ) { req in
                    (await viewModel.setBillingGroup(req)) ? nil : (viewModel.actionError ?? "Could not update billing group.")
                }
            }
        }
        .confirmationDialog(
            "Recreate Order",
            isPresented: $showRecreateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Recreate", role: .destructive) {
                showRecreateSheet = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cancels the original order and creates a new order with the same devices and items. This cannot be undone.")
        }
        .sheet(isPresented: $showRecreateSheet) {
            RecreateOrderSheet(client: viewModel.order?.client) { req in
                guard await viewModel.recreateOrder(req) else {
                    return viewModel.actionError ?? "Could not recreate order."
                }
                if let newOrderNumber = viewModel.recreatedOrderNumber {
                    recreateSuccessMessage = "New order #\(newOrderNumber) created. The original order has been cancelled."
                } else {
                    recreateSuccessMessage = "New order created. The original order has been cancelled."
                }
                return nil
            }
        }
        .alert(
            "Order Recreated",
            isPresented: Binding(
                get: { recreateSuccessMessage != nil },
                set: { if !$0 { recreateSuccessMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { recreateSuccessMessage = nil }
        } message: {
            Text(recreateSuccessMessage ?? "")
        }
        // MARK: - Device Action Sheets
        .sheet(item: $dueDateDevice) { device in
            OrderDeviceDueDateSheet(deviceName: device.displayName ?? "Device") { dateString in
                (await viewModel.updateDeviceDueDate(deviceId: device.id, dueDate: dateString)) ? nil : (viewModel.actionError ?? "Could not update due date.")
            }
        }
        .confirmationDialog(
            "Delete Device",
            isPresented: $showDeleteDeviceConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let device = deviceToDelete {
                    Task { _ = await viewModel.deleteDevice(deviceId: device.id) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let device = deviceToDelete {
                Text("Are you sure you want to delete \"\(device.displayName ?? "this device")\"? This cannot be undone.")
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
                    HStack(spacing: 4) {
                        // Navigation button — tapping the row navigates to device detail.
                        Button {
                            selectedDeviceNav = DeviceNavTarget(id: device.id, orderId: orderId)
                        } label: {
                            deviceRow(device)
                        }
                        .buttonStyle(.plain)

                        // Per-device action menu — a sibling control (NOT nested inside
                        // the navigation Button) so tapping it doesn't trigger navigation.
                        if viewModel.isOrderEditable {
                            Menu {
                                Button {
                                    dueDateDevice = device
                                } label: {
                                    Label("Edit due date", systemImage: "calendar")
                                }
                                Button(role: .destructive) {
                                    deviceToDelete = device
                                    showDeleteDeviceConfirmation = true
                                } label: {
                                    Label("Delete device", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 32)
                            }
                            .accessibilityIdentifier("device-menu-\(device.id)")
                        }
                    }

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

    private func totalsSection(_ totals: OrderTotals, order: Order) -> some View {
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

                if let discountTotal = totals.discountTotal, discountTotal > 0 {
                    totalRow("Discount", value: "-\(CurrencyFormatter.format(discountTotal))", color: .orange)
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

                    PaymentStatusBadge(status: order.effectivePaymentStatus)

                    Text(totals.formattedBalanceDue)
                        .fontWeight(.bold)
                        .foregroundStyle(totals.balanceDue > 0 ? .red : .green)
                }

                Divider()

                globalDiscountRow(order)
            }
        }
    }

    // MARK: - Global Discount Row

    @ViewBuilder
    private func globalDiscountRow(_ order: Order) -> some View {
        let hasDiscount = (order.globalDiscountPercent ?? 0) > 0 || (order.globalDiscountAmount ?? 0) > 0

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Order Discount")
                    .font(.subheadline).fontWeight(.medium)
                if hasDiscount {
                    Text(discountDescription(order))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No discount applied")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if viewModel.isOrderEditable {
                Button(hasDiscount ? "Edit discount" : "Add discount") {
                    showDiscountSheet = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("order-discount-edit")
            }
        }
    }

    private func discountDescription(_ order: Order) -> String {
        var parts: [String] = []
        if let percent = order.globalDiscountPercent, percent > 0 {
            parts.append(String(format: "%.0f%% off", percent))
        } else if let amount = order.globalDiscountAmount, amount > 0 {
            parts.append("\(CurrencyFormatter.format(amount)) off")
        }
        if let reason = order.globalDiscountReason, !reason.isEmpty {
            parts.append(reason)
        }
        return parts.joined(separator: " — ")
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

    // MARK: - Close-out Actions Section

    private func closeOutActionsSection(_ order: Order) -> some View {
        SectionCard(title: "Actions", icon: "checklist") {
            VStack(spacing: 8) {
                if order.status == .pending || order.status == .awaitingDevice || order.status == .inProgress {
                    Button {
                        showAuthorizeSheet = true
                    } label: {
                        Label("Authorize", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { _ = await viewModel.sendQuote() }
                    } label: {
                        Label("Send quote", systemImage: "paperplane")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isPerformingAction)
                }

                if order.status == .awaitingCollection || order.status == .serviceComplete {
                    Button {
                        showCollectSheet = true
                    } label: {
                        Label("Mark collected", systemImage: "hand.thumbsup")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showDespatchSheet = true
                    } label: {
                        Label("Despatch", systemImage: "shippingbox")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    showAddNoteSheet = true
                } label: {
                    Label("Add note", systemImage: "note.text.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let actionError = viewModel.actionError {
                    Text(actionError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .accessibilityIdentifier("order-actions")
    }

    // MARK: - Admin Section (Package G)

    private func adminSection(_ order: Order) -> some View {
        SectionCard(title: "Admin", icon: "gearshape") {
            VStack(alignment: .leading, spacing: 12) {
                // Purchase order row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Purchase Order")
                            .font(.subheadline).fontWeight(.medium)
                        if let reference = order.customerPoReference, !reference.isEmpty {
                            Text(reference)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let value = order.customerPoValue {
                            Text(CurrencyFormatter.format(value))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if order.customerPoReference == nil && order.customerPoValue == nil {
                            Text("No purchase order recorded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if viewModel.isOrderEditable {
                        Button("Edit") {
                            showPurchaseOrderSheet = true
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("po-edit")
                    }
                }

                Divider()

                // Billing group row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Billing Group")
                            .font(.subheadline).fontWeight(.medium)
                        Text(order.billingGroup?.name ?? "None")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if viewModel.isOrderEditable {
                        Button(order.billingGroup != nil ? "Change" : "Set") {
                            showBillingGroupSheet = true
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("billing-group-edit")
                    }
                }

                // Recreate order — admin only (backend returns 403 for non-admins),
                // and only meaningful while the order hasn't already been cancelled.
                if AuthManager.shared.currentUser?.role.isAdmin == true && order.status != .cancelled {
                    Divider()

                    Button(role: .destructive) {
                        showRecreateConfirmation = true
                    } label: {
                        Label("Recreate order", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .accessibilityIdentifier("order-admin")
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
            case .unknown: return ("Unknown", .gray)
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

            VStack(alignment: .trailing, spacing: 4) {
                Text(payment.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(amountColor)
                    .strikethrough(payment.isFullyRefunded, color: .secondary)

                if payment.isRefundable == true, (payment.refundableAmount ?? 0) > 0 {
                    Button {
                        refundTarget = payment
                    } label: {
                        Label("Refund", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.orange)
                }
            }
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

                        Button(role: .destructive) {
                            refundToDelete = refund
                            showDeleteRefundAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
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

    // MARK: - Customer Section

    /// Shows a read-only view of the order's ticket conversation plus
    /// reply / resolve / reopen actions. Gated on `order.ticketId != nil`.
    private func customerSection(_ order: Order) -> some View {
        let ticket = order.ticket
        let isClosedOrResolved = ["resolved", "closed"].contains(ticket?.status?.lowercased() ?? "")

        return SectionCard(title: "Customer", icon: "bubble.left.and.bubble.right") {
            VStack(alignment: .leading, spacing: 12) {
                if let status = ticket?.status {
                    HStack {
                        Text("Ticket status")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(status.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((isClosedOrResolved ? Color.gray : Color.green).opacity(0.15))
                            .foregroundStyle(isClosedOrResolved ? .gray : .green)
                            .clipShape(Capsule())
                    }
                }

                if let messages = ticket?.messages, !messages.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            ticketMessageRow(message)
                            if message.id != messages.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    Button {
                        showReplySheet = true
                    } label: {
                        Label("Reply to customer", systemImage: "paperplane")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isClosedOrResolved || viewModel.isPerformingAction)
                    .accessibilityIdentifier("order-reply-to-customer")

                    if isClosedOrResolved {
                        Button {
                            Task { _ = await viewModel.reopenTicket() }
                        } label: {
                            Label("Reopen", systemImage: "arrow.uturn.backward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isPerformingAction)
                        .accessibilityIdentifier("order-reopen-ticket")
                    } else {
                        Button {
                            showResolveConfirmation = true
                        } label: {
                            Label("Resolve", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .disabled(viewModel.isPerformingAction)
                        .accessibilityIdentifier("order-resolve-ticket")
                    }
                }

                if let actionError = viewModel.actionError {
                    Text(actionError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
    }

    private func ticketMessageRow(_ message: OrderTicketMessage) -> some View {
        let isInbound = message.type == "email_inbound" || message.type == "sms_inbound"
        let isNote = message.type == "note"

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(isNote ? "Note" : (message.fromName ?? (isInbound ? "Customer" : "Staff")))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isNote ? .orange : (isInbound ? .blue : .primary))

                Spacer()

                if let createdAt = message.createdAt {
                    Text(DateFormatters.formatRelativeDate(createdAt) ?? createdAt)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(message.bodyText ?? message.bodyHtml?.strippingHTML() ?? "")
                .font(.subheadline)
                .foregroundStyle(.primary)
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

    /// Record on the ticket that the customer was given their intake receipt.
    /// Best-effort — a failed note must never look like a failed handover, so
    /// nothing is surfaced to the user beyond the view model's own error state.
    private func logBookingReceiptShared(_ order: Order) {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy 'at' HH:mm"
        formatter.locale = Locale(identifier: "en_GB")
        let note = "Booking receipt for order #\(order.orderNumber) shared with the customer on \(formatter.string(from: Date()))."

        Task { _ = await viewModel.addNote(CreateTicketNoteRequest(body: note, deviceId: nil)) }
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
