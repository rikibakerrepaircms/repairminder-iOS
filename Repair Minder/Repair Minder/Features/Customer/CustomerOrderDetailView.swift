//
//  CustomerOrderDetailView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Customer order detail screen
struct CustomerOrderDetailView: View {
    @StateObject private var viewModel: CustomerOrderDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(orderId: String) {
        _viewModel = StateObject(wrappedValue: CustomerOrderDetailViewModel(orderId: orderId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.order == nil {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.order == nil {
                errorView(error)
            } else if let order = viewModel.order {
                orderContent(order)
            } else {
                // Fallback: no loading, no error, no order
                errorView("Unable to load order details")
            }
        }
        .navigationTitle(viewModel.order?.orderReference ?? "Order")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $viewModel.showApprovalSheet) {
            if let order = viewModel.order {
                CustomerApprovalSheet(
                    order: order,
                    viewModel: viewModel
                )
            }
        }
        .sheet(isPresented: $viewModel.showMessageCompose) {
            messageComposeSheet
        }
        .task {
            await viewModel.loadOrder()
        }
    }

    // MARK: - Order Content

    private func orderContent(_ order: CustomerOrderDetail) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Order Header
                orderHeader(order)

                // Pre-Authorization Banner (if applicable)
                if let preAuth = order.preAuthorization {
                    preAuthBanner(preAuth, order: order)
                }

                // Action Required Banner
                if order.isAwaitingAction {
                    actionRequiredBanner(order)
                }

                // Approval Success Banner
                if viewModel.approvalSuccess {
                    approvalSuccessBanner(order)
                }

                // Devices Section
                ForEach(order.devices) { device in
                    CustomerDeviceCard(
                        device: device,
                        items: order.items(for: device.id),
                        currencyCode: order.currencyCode,
                        onApprove: order.isAwaitingAction ? {
                            viewModel.selectedDeviceForApproval = device
                            viewModel.showApprovalSheet = true
                        } : nil
                    )
                }

                // Order Totals
                if !order.items.isEmpty {
                    orderTotals(order)
                }

                // Messages Section
                if !order.messages.isEmpty {
                    messagesSection(order.messages)
                }

                // Contact Section
                if let company = order.company {
                    contactSection(company)
                }

                // Review Links (for completed orders)
                if order.shouldShowReviewLinks, let reviewLinks = order.reviewLinks {
                    reviewLinksSection(reviewLinks)
                }
            }
            .padding()
            .frame(maxWidth: horizontalSizeClass == .regular ? 700 : .infinity)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Order Header

    private func orderHeader(_ order: CustomerOrderDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order \(order.orderReference)")
                        .font(.headline)

                    Text(formatDate(order.createdAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusBadge(for: order)
            }

            if let company = order.company {
                HStack {
                    Image(systemName: "building.2")
                        .foregroundStyle(.secondary)
                    Text(company.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Pre-Authorization Banner

    private func preAuthBanner(_ preAuth: PreAuthorization, order: CustomerOrderDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("Pre-Authorized")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
            }

            Text("You pre-approved repairs up to \(viewModel.formatCurrency(preAuth.amount))")
                .font(.subheadline)

            if let notes = preAuth.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Action Required Banner

    private func actionRequiredBanner(_ order: CustomerOrderDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("Action Required")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
            }

            Text("Please review the \(order.devices.first?.quoteLabel.lowercased() ?? "quote") below and approve or decline.")
                .font(.subheadline)

            Button {
                viewModel.showApprovalSheet = true
            } label: {
                Text("Review & Respond")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Approval Success Banner

    private func approvalSuccessBanner(_ order: CustomerOrderDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: order.isRejected ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(order.isRejected ? .red : .green)
                Text(order.isRejected ? "Quote Declined" : "Quote Approved")
                    .font(.headline)
                    .foregroundStyle(order.isRejected ? .red : .green)
                Spacer()
            }

            Text(order.isRejected
                ? "You have declined the quote. Please contact us to arrange collection of your device."
                : "Thank you! Your quote has been approved. We'll begin work shortly.")
                .font(.subheadline)
        }
        .padding()
        .background((order.isRejected ? Color.red : Color.green).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Order Totals

    private func orderTotals(_ order: CustomerOrderDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Total")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Text("Subtotal")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.formatCurrency(order.totals.subtotal))
                }

                HStack {
                    Text("VAT")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.formatCurrency(order.totals.vatTotal))
                }

                Divider()

                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(viewModel.formatCurrency(order.totals.grandTotal))
                        .fontWeight(.semibold)
                }

                if let paid = order.totals.amountPaid, paid > 0 {
                    HStack {
                        Text("Paid")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("-\(viewModel.formatCurrency(paid))")
                            .foregroundStyle(.green)
                    }

                    if let balance = order.totals.balanceDue, balance > 0 {
                        HStack {
                            Text("Balance Due")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(viewModel.formatCurrency(balance))
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Messages Section

    private func messagesSection(_ messages: [CustomerMessage]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Messages")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.showMessageCompose = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.caption)
                        Text("Reply")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }

            ForEach(messages) { message in
                CustomerMessageBubble(message: message)
            }
        }
        .padding()
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Need Help Section

    private func contactSection(_ company: CustomerCompanyInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Need Help?")
                .font(.headline)

            // Messaging prompt
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "message.fill")
                    .foregroundStyle(.blue)
                    .font(.subheadline)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Send us a message above")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Messaging here doesn't interrupt our queue, which helps us turn jobs around faster.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Location & phone fallback
            VStack(alignment: .leading, spacing: 8) {
                Text("Need to reach us another way?")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 6) {
                    if company.locationName != nil || company.formattedAddress != nil {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                                .frame(width: 20)
                                .padding(.top, 1)

                            VStack(alignment: .leading, spacing: 2) {
                                if let locationName = company.locationName {
                                    Text(locationName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }

                                if let address = company.formattedAddress {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if let phone = company.phone {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                                .frame(width: 20)

                            Button {
                                if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                                    #if os(iOS)
                                    UIApplication.shared.open(url)
                                    #elseif os(macOS)
                                    NSWorkspace.shared.open(url)
                                    #endif
                                }
                            } label: {
                                Text(phone)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.platformGray6)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Review Links Section

    private func reviewLinksSection(_ reviewLinks: ReviewLinks) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leave a Review")
                .font(.headline)

            Text("Happy with our service? We'd love to hear from you!")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(reviewLinks.availableLinks, id: \.name) { link in
                    Button {
                        if let url = URL(string: link.url),
                           let scheme = url.scheme?.lowercased(),
                           ["https", "http"].contains(scheme) {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #elseif os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: link.icon)
                                .font(.title2)
                            Text(link.name)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Message Compose Sheet

    private var messageComposeSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message input area
                VStack(spacing: 12) {
                    TextEditor(text: $viewModel.newMessageText)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let error = viewModel.messageError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()

                Spacer()

                // Bottom input bar like iMessage
                HStack(spacing: 12) {
                    Spacer()

                    Button {
                        Task {
                            await viewModel.sendMessage()
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingMessage
                                ? Color.gray
                                : Color.blue
                            )
                    }
                    .disabled(viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingMessage)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Send Message")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showMessageCompose = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Loading View

    private var loadingView: some View {
        LottieLoadingView(size: 100, message: "Loading order...")
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task {
                    await viewModel.loadOrder()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Status Badge

    private func statusBadge(for order: CustomerOrderDetail) -> some View {
        let (text, color) = statusInfo(for: order)

        return Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func statusInfo(for order: CustomerOrderDetail) -> (String, Color) {
        if order.isRejected {
            return ("Declined", .red)
        }
        if order.isComplete {
            return ("Complete", .green)
        }
        if order.isApproved {
            return ("Approved", .green)
        }
        if order.isAwaitingAction {
            return ("Action Required", .orange)
        }
        return ("In Progress", .blue)
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        DateFormatters.formatHumanDate(date)
    }
}

// MARK: - Message Bubble

struct CustomerMessageBubble: View {
    let message: CustomerMessage

    var body: some View {
        VStack(alignment: message.isFromCustomer ? .trailing : .leading, spacing: 4) {
            HStack {
                if message.isFromCustomer {
                    Spacer()
                }

                VStack(alignment: message.isFromCustomer ? .trailing : .leading, spacing: 4) {
                    if let subject = message.subject, !subject.isEmpty {
                        Text(subject)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    if let body = message.bodyText {
                        Text(body)
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: 500)
                .padding(12)
                .background(message.backgroundColor)
                .foregroundStyle(message.textColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if !message.isFromCustomer {
                    Spacer()
                }
            }

            HStack(spacing: 4) {
                if message.isFromCustomer {
                    Spacer()
                }
                Image(systemName: message.typeIcon)
                    .font(.caption2)
                Text(message.formattedDate)
                    .font(.caption2)
                if !message.isFromCustomer {
                    Spacer()
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CustomerOrderDetailView(orderId: "test-order-id")
    }
}
