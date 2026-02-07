//
//  CustomerOrderListView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Customer order list screen
struct CustomerOrderListView: View {
    @StateObject private var viewModel = CustomerOrderListViewModel()
    @ObservedObject private var customerAuth = CustomerAuthManager.shared
    @ObservedObject private var appState = AppState.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedOrderId: String?

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if isRegularWidth {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task {
            await viewModel.loadOrders()
        }
        .onChange(of: viewModel.orders.isEmpty) { _, isEmpty in
            if !isEmpty && isRegularWidth && selectedOrderId == nil {
                selectedOrderId = viewModel.actionRequiredOrders.first?.id
                    ?? viewModel.orders.first?.id
            }
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.orders.isEmpty {
                    errorView(error)
                } else if viewModel.orders.isEmpty {
                    emptyView
                } else {
                    orderList
                }
            }
            .navigationTitle("My Orders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    profileMenu
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            Group {
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.orders.isEmpty {
                    errorView(error)
                } else if viewModel.orders.isEmpty {
                    emptyView
                } else {
                    iPadOrderList
                }
            }
            .navigationTitle("My Orders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    profileMenu
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        } detail: {
            if let orderId = selectedOrderId {
                CustomerOrderDetailView(orderId: orderId)
            } else {
                ContentUnavailableView(
                    "Select an Order",
                    systemImage: "doc.text",
                    description: Text("Choose an order from the list to view its details.")
                )
            }
        }
    }

    // MARK: - iPhone Order List

    private var orderList: some View {
        List {
            // Action Required Section
            if !viewModel.actionRequiredOrders.isEmpty {
                Section {
                    ForEach(viewModel.actionRequiredOrders) { order in
                        NavigationLink(destination: CustomerOrderDetailView(orderId: order.id)) {
                            CustomerOrderRow(
                                order: order,
                                currencyCode: viewModel.currencyCode
                            )
                        }
                    }
                } header: {
                    Label("Action Required", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                }
            }

            // Active Orders Section
            let activeNonActionOrders = viewModel.activeOrders.filter { !$0.isAwaitingAction }
            if !activeNonActionOrders.isEmpty {
                Section {
                    ForEach(activeNonActionOrders) { order in
                        NavigationLink(destination: CustomerOrderDetailView(orderId: order.id)) {
                            CustomerOrderRow(
                                order: order,
                                currencyCode: viewModel.currencyCode
                            )
                        }
                    }
                } header: {
                    Text("In Progress")
                }
            }

            // Completed Orders Section
            if !viewModel.completedOrders.isEmpty {
                Section {
                    ForEach(viewModel.completedOrders) { order in
                        NavigationLink(destination: CustomerOrderDetailView(orderId: order.id)) {
                            CustomerOrderRow(
                                order: order,
                                currencyCode: viewModel.currencyCode
                            )
                        }
                    }
                } header: {
                    Text("Completed")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - iPad Order List

    private var iPadOrderList: some View {
        List(selection: $selectedOrderId) {
            // Action Required Section
            if !viewModel.actionRequiredOrders.isEmpty {
                Section {
                    ForEach(viewModel.actionRequiredOrders) { order in
                        CustomerOrderRow(
                            order: order,
                            currencyCode: viewModel.currencyCode,
                            isWideLayout: true
                        )
                        .tag(order.id)
                    }
                } header: {
                    Label("Action Required", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                }
            }

            // Active Orders Section
            let activeNonActionOrders = viewModel.activeOrders.filter { !$0.isAwaitingAction }
            if !activeNonActionOrders.isEmpty {
                Section {
                    ForEach(activeNonActionOrders) { order in
                        CustomerOrderRow(
                            order: order,
                            currencyCode: viewModel.currencyCode,
                            isWideLayout: true
                        )
                        .tag(order.id)
                    }
                } header: {
                    Text("In Progress")
                }
            }

            // Completed Orders Section
            if !viewModel.completedOrders.isEmpty {
                Section {
                    ForEach(viewModel.completedOrders) { order in
                        CustomerOrderRow(
                            order: order,
                            currencyCode: viewModel.currencyCode,
                            isWideLayout: true
                        )
                        .tag(order.id)
                    }
                } header: {
                    Text("Completed")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)

            Text("Loading orders...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
                    await viewModel.loadOrders()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Orders Yet")
                .font(.headline)

            Text("When you have repair or buyback orders, they'll appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Profile Menu

    private var profileMenu: some View {
        Menu {
            if let client = customerAuth.currentCustomerClient {
                Section {
                    Text(client.displayName)
                    Text(client.email)
                        .font(.caption)
                }
            }

            if let company = customerAuth.currentCompany {
                Section {
                    Label(company.name, systemImage: "building.2")
                }
            }

            Divider()

            Button("Switch Role") {
                Task {
                    await appState.switchRole()
                }
            }

            Button("Logout", role: .destructive) {
                Task {
                    await customerAuth.logout()
                    appState.onCustomerLogout()
                }
            }
        } label: {
            Image(systemName: "person.circle")
                .imageScale(.large)
        }
    }
}

// MARK: - Order Row

/// Row component for order list
struct CustomerOrderRow: View {
    let order: CustomerOrderSummary
    let currencyCode: String
    var isWideLayout: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with order number and status
            HStack {
                Text(order.orderReference)
                    .font(.headline)

                Spacer()

                statusBadge
            }

            // Devices list
            if isWideLayout {
                HStack(spacing: 6) {
                    Image(systemName: "iphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(order.devices.map(\.displayName).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if order.devices.count > 1 {
                        Text("\(order.devices.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(order.devices) { device in
                        HStack(spacing: 6) {
                            Image(systemName: "iphone")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(device.displayName)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                    }
                }
            }

            // Footer with date and total
            HStack {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatCurrency(order.totals.grandTotal))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        let (text, color) = statusInfo

        return Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var statusInfo: (String, Color) {
        if order.isRejected {
            return ("Declined", .red)
        }
        if order.isApproved {
            return ("Approved", .green)
        }
        if order.isAwaitingAction {
            return ("Action Required", .orange)
        }

        // Check device statuses
        if let firstDevice = order.devices.first {
            switch firstDevice.status {
            case "device_received":
                return ("Received", .gray)
            case "diagnosing":
                return ("Being Assessed", .purple)
            case "repairing":
                return ("Being Repaired", .teal)
            case "repaired_qc":
                return ("Quality Check", .pink)
            case "repaired_ready", "rejection_ready":
                return ("Ready", .green)
            case "collected", "despatched":
                return ("Complete", .green)
            case "payment_made":
                return ("Paid", .green)
            default:
                return ("In Progress", .blue)
            }
        }

        return ("In Progress", .blue)
    }

    // MARK: - Formatting

    private var formattedDate: String {
        DateFormatters.formatHumanDate(order.createdAt)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: amount as NSDecimalNumber) ?? "£\(amount)"
    }
}

// MARK: - Preview

#Preview {
    CustomerOrderListView()
}
