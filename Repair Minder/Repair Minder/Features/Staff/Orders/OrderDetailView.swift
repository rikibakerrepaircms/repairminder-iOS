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
                    devicesSection(devices)
                }

                // Items section
                if let items = order.items, !items.isEmpty {
                    itemsSection(items)
                }

                // Totals section
                if let totals = order.totals {
                    totalsSection(totals, paymentStatus: order.effectivePaymentStatus)
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
            }
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
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
        .background(Color(.systemBackground))
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
                .buttonStyle(.plain)

                if let address = client.fullAddress {
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

    private func devicesSection(_ devices: [OrderDeviceSummary]) -> some View {
        SectionCard(title: "Devices", icon: "iphone") {
            VStack(spacing: 8) {
                ForEach(devices) { device in
                    HStack {
                        Circle()
                            .fill(device.deviceStatus.color)
                            .frame(width: 8, height: 8)

                        Text(device.deviceStatus.label)
                            .font(.subheadline)

                        Spacer()

                        if let auth = device.authorizationStatus {
                            Text(auth.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if device.id != devices.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Items Section

    private func itemsSection(_ items: [OrderItem]) -> some View {
        SectionCard(title: "Items", icon: "list.bullet") {
            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description)
                                .font(.subheadline)

                            if let type = item.itemType {
                                Text(type.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.formattedLineTotal)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("x\(item.quantity)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Totals Section

    private func totalsSection(_ totals: OrderTotals, paymentStatus: PaymentStatus) -> some View {
        SectionCard(title: "Totals", icon: "sum") {
            VStack(spacing: 8) {
                totalRow("Subtotal", value: totals.formattedSubtotal)
                totalRow("VAT", value: totals.formattedVatTotal)

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

    // MARK: - Payments Section

    private func paymentsSection(_ payments: [OrderPayment]) -> some View {
        SectionCard(title: "Payments", icon: "creditcard") {
            VStack(spacing: 8) {
                ForEach(payments) { payment in
                    HStack {
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
                            }

                            if let date = payment.formattedDate {
                                Text(date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text(payment.formattedAmount)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)

                    if payment.id != payments.last?.id {
                        Divider()
                    }
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
        SectionCard(title: "Timeline", icon: "clock") {
            VStack(spacing: 8) {
                if let created = dates.createdAt {
                    dateRow("Created", date: created)
                }
                if let quoteSent = dates.quoteSentAt {
                    dateRow("Quote Sent", date: quoteSent)
                }
                if let authorised = dates.authorisedAt {
                    dateRow("Authorised", date: authorised)
                }
                if let rejected = dates.rejectedAt {
                    dateRow("Rejected", date: rejected, color: .red)
                }
                if let completed = dates.serviceCompletedAt {
                    dateRow("Service Completed", date: completed)
                }
                if let collected = dates.collectedAt {
                    dateRow("Collected", date: collected, color: .green)
                }
                if let despatched = dates.despatchedAt {
                    dateRow("Despatched", date: despatched, color: .green)
                }
            }
        }
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

    // MARK: - Loading & Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading order...")
                .foregroundStyle(.secondary)
        }
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

#Preview {
    NavigationStack {
        OrderDetailView(orderId: "test")
    }
}
