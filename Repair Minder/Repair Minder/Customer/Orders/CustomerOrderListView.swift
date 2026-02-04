//
//  CustomerOrderListView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct CustomerOrderListView: View {
    @State private var viewModel = CustomerOrderListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    LoadingView(message: "Loading orders...")
                } else if let error = viewModel.error, viewModel.orders.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.loadOrders() }
                    }
                } else if viewModel.orders.isEmpty {
                    ContentUnavailableView {
                        Label("No Repairs", systemImage: "wrench.and.screwdriver")
                    } description: {
                        Text("You don't have any repair orders yet")
                    }
                } else {
                    orderListContent
                }
            }
            .navigationTitle("My Repairs")
            .navigationDestination(for: String.self) { orderId in
                CustomerOrderDetailView(orderId: orderId)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                if viewModel.orders.isEmpty {
                    await viewModel.loadOrders()
                }
            }
        }
    }

    private var orderListContent: some View {
        List {
            // Active orders section
            if !activeOrders.isEmpty {
                Section {
                    ForEach(activeOrders) { order in
                        NavigationLink(value: order.id) {
                            CustomerOrderRow(order: order)
                        }
                    }
                } header: {
                    Text("Active")
                }
            }

            // Orders requiring action
            if !ordersNeedingAction.isEmpty {
                Section {
                    ForEach(ordersNeedingAction) { order in
                        NavigationLink(value: order.id) {
                            CustomerOrderRow(order: order, showsActionBadge: true)
                        }
                    }
                } header: {
                    Label("Action Required", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                }
            }

            // Completed orders
            if !completedOrders.isEmpty {
                Section {
                    ForEach(completedOrders) { order in
                        NavigationLink(value: order.id) {
                            CustomerOrderRow(order: order)
                        }
                    }
                } header: {
                    Text("Completed")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Computed Properties

    private var activeOrders: [CustomerOrder] {
        viewModel.orders.filter { $0.status.isActive && !$0.status.requiresAction }
    }

    private var ordersNeedingAction: [CustomerOrder] {
        viewModel.orders.filter { $0.status.requiresAction }
    }

    private var completedOrders: [CustomerOrder] {
        viewModel.orders.filter { !$0.status.isActive }
    }
}

// MARK: - Customer Order Row

struct CustomerOrderRow: View {
    let order: CustomerOrder
    var showsActionBadge: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.displayRef)
                    .font(.headline)

                Spacer()

                CustomerOrderStatusBadge(status: order.status)
            }

            Text(order.deviceSummary.isEmpty ? "Device" : order.deviceSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(order.createdAt.relativeFormatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let balance = order.balance, balance > 0 {
                    Spacer()
                    Text("Balance: \(balance.formatted(.currency(code: "GBP")))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }

            if showsActionBadge {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("Quote ready for approval")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Customer Order Status Badge

struct CustomerOrderStatusBadge: View {
    let status: CustomerOrderStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.customerDisplayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .foregroundStyle(status.color)
        .clipShape(Capsule())
    }
}

#Preview {
    CustomerOrderListView()
}
