//
//  OrderDetailView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct OrderDetailView: View {
    let orderId: String
    @StateObject private var viewModel: OrderDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(orderId: String) {
        self.orderId = orderId
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(orderId: orderId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(message: "Loading order...")
            } else if let order = viewModel.order {
                ScrollView {
                    VStack(spacing: 20) {
                        OrderDetailHeader(order: order)

                        if order.status.isActive {
                            StatusActionsView(
                                currentStatus: order.status,
                                isUpdating: viewModel.isUpdating,
                                onStatusChange: { status in
                                    Task { await viewModel.updateStatus(status) }
                                }
                            )
                        }

                        ClientInfoCard(order: order)

                        DevicesSection(devices: viewModel.devices)

                        PaymentSummary(order: order)

                        if let notes = order.notes, !notes.isEmpty {
                            NotesSection(notes: notes)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    Task { await viewModel.loadOrder() }
                }
            }
        }
        .navigationTitle(viewModel.order?.displayRef ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadOrder()
        }
    }
}

struct OrderDetailHeader: View {
    let order: Order

    var body: some View {
        VStack(spacing: 8) {
            Text(order.displayRef)
                .font(.largeTitle)
                .fontWeight(.bold)

            OrderStatusBadge(status: order.status, size: .large)

            Text("Created \(order.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        OrderDetailView(orderId: "test-id")
    }
}
