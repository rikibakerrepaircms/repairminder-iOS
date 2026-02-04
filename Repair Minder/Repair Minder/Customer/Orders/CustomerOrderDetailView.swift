//
//  CustomerOrderDetailView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct CustomerOrderDetailView: View {
    let orderId: String
    @State private var viewModel: CustomerOrderDetailViewModel
    @State private var showRejectSheet = false
    @State private var rejectReason = ""

    init(orderId: String) {
        self.orderId = orderId
        _viewModel = State(initialValue: CustomerOrderDetailViewModel(orderId: orderId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading && viewModel.order == nil {
                    LoadingView(message: "Loading order...")
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let error = viewModel.error, viewModel.order == nil {
                    ErrorView(message: error) {
                        Task { await viewModel.loadOrder() }
                    }
                } else if let order = viewModel.order {
                    // Status header
                    OrderTrackingHeader(order: order)

                    // Quote approval card (if applicable)
                    if order.status == .awaitingApproval {
                        QuoteApprovalCard(
                            order: order,
                            quote: viewModel.quote,
                            isLoading: viewModel.isApprovingQuote,
                            onApprove: {
                                Task { await viewModel.approveQuote() }
                            },
                            onReject: {
                                showRejectSheet = true
                            }
                        )
                    }

                    // Success/Error messages
                    if let success = viewModel.successMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(success)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Timeline
                    OrderTimeline(events: viewModel.timeline)

                    // Devices section
                    if let devices = order.devices, !devices.isEmpty {
                        DevicesStatusSection(devices: devices)
                    }

                    // Payment info
                    if let balance = order.balance, balance > 0 {
                        PaymentDueCard(balance: balance, deposit: order.deposit)
                    }

                    // Contact button
                    NavigationLink {
                        ConversationView(orderId: order.id)
                    } label: {
                        Label("Contact Shop", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(viewModel.order?.displayRef ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadOrder()
        }
        .task {
            await viewModel.loadOrder()
        }
        .sheet(isPresented: $showRejectSheet) {
            RejectReasonSheet(
                reason: $rejectReason,
                isLoading: viewModel.isApprovingQuote,
                onSubmit: {
                    Task {
                        await viewModel.rejectQuote(reason: rejectReason)
                        showRejectSheet = false
                        rejectReason = ""
                    }
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        CustomerOrderDetailView(orderId: "test-order-id")
    }
}
