//
//  OrderListView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

struct OrderListView: View {
    @StateObject private var viewModel = OrderListViewModel()
    @State private var showingFilters = false
    @State private var selectedOrder: Order?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Compact Filter Header
                filterHeader

                // Main content
                Group {
                    if viewModel.isLoading && viewModel.orders.isEmpty {
                        loadingView
                    } else if let error = viewModel.error, viewModel.orders.isEmpty {
                        errorView(error)
                    } else if viewModel.orders.isEmpty {
                        emptyView
                    } else {
                        ordersList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    filterButton
                }
            }
            .sheet(isPresented: $showingFilters) {
                OrderFilterSheet(viewModel: viewModel)
            }
            .navigationDestination(item: $selectedOrder) { order in
                OrderDetailView(orderId: order.id)
            }
        }
        .task {
            await viewModel.loadOrders()
        }
    }

    // MARK: - Filter Header

    private var filterHeader: some View {
        VStack(spacing: 6) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search orders...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        viewModel.searchText = newValue
                        viewModel.searchOrders()
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        viewModel.searchText = ""
                        viewModel.searchOrders()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
            .cornerRadius(8)

            // Status Filter Boxes
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // All status option
                    OrderStatusBox(
                        label: "All",
                        isSelected: viewModel.selectedStatus == nil,
                        color: .blue
                    ) {
                        viewModel.selectedStatus = nil
                        Task { await viewModel.applyFilter() }
                    }

                    ForEach(OrderStatus.allCases, id: \.rawValue) { status in
                        OrderStatusBox(
                            label: status.shortLabel,
                            isSelected: viewModel.selectedStatus == status.rawValue,
                            color: status.color
                        ) {
                            viewModel.selectedStatus = viewModel.selectedStatus == status.rawValue ? nil : status.rawValue
                            Task { await viewModel.applyFilter() }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Subviews

    private var ordersList: some View {
        List {
            ForEach(viewModel.orders) { order in
                OrderRowView(order: order)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedOrder = order
                    }
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: order)
                    }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading orders...")
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
                    await viewModel.loadOrders()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Orders", systemImage: "doc.text")
        } description: {
            if viewModel.hasActiveFilters {
                Text("No orders match your filters")
            } else {
                Text("Orders will appear here")
            }
        } actions: {
            if viewModel.hasActiveFilters {
                Button("Clear Filters") {
                    Task {
                        await viewModel.clearFilters()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var filterButton: some View {
        Button {
            showingFilters = true
        } label: {
            Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
}

// MARK: - Order Row View

struct OrderRowView: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Text(order.formattedOrderNumber)
                    .font(.headline)

                Spacer()

                OrderStatusBadge(status: order.status)
            }

            // Client info
            HStack {
                Image(systemName: "person")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text(order.clientDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Bottom row
            HStack {
                PaymentStatusBadge(status: order.effectivePaymentStatus)

                Spacer()

                Text(CurrencyFormatter.format(order.displayTotal))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            // Notes preview if available
            if let firstNote = order.notes?.first {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Text(firstNote.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }

            // Date
            if let date = order.formattedCreatedDate {
                Text(date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badges

struct OrderStatusBadge: View {
    let status: OrderStatus

    var body: some View {
        Text(status.label)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.backgroundColor)
            .clipShape(Capsule())
    }
}

struct PaymentStatusBadge: View {
    let status: PaymentStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.label)
                .font(.caption)
        }
        .fontWeight(.medium)
        .foregroundStyle(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.backgroundColor)
        .clipShape(Capsule())
    }
}

// MARK: - Filter Sheet

struct OrderFilterSheet: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Status filter
                Section("Status") {
                    Picker("Order Status", selection: $viewModel.selectedStatus) {
                        Text("All").tag(nil as String?)
                        ForEach(OrderStatus.allCases, id: \.rawValue) { status in
                            Text(status.label).tag(status.rawValue as String?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Payment status filter
                Section("Payment") {
                    Picker("Payment Status", selection: $viewModel.selectedPaymentStatus) {
                        Text("All").tag(nil as String?)
                        ForEach(PaymentStatus.allCases, id: \.rawValue) { status in
                            Text(status.label).tag(status.rawValue as String?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Location filter
                if let locations = viewModel.filters?.locations, !locations.isEmpty {
                    Section("Location") {
                        Picker("Location", selection: $viewModel.selectedLocationId) {
                            Text("All Locations").tag(nil as String?)
                            ForEach(locations) { location in
                                Text(location.name).tag(location.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // Assigned user filter
                if let users = viewModel.filters?.users, !users.isEmpty {
                    Section("Assigned To") {
                        Picker("Technician", selection: $viewModel.selectedUserId) {
                            Text("Anyone").tag(nil as String?)
                            Text("Unassigned").tag("unassigned" as String?)
                            ForEach(users) { user in
                                Text(user.name).tag(user.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // Clear filters
                if viewModel.hasActiveFilters {
                    Section {
                        Button("Clear All Filters", role: .destructive) {
                            Task {
                                await viewModel.clearFilters()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        Task {
                            await viewModel.applyFilter()
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Order Status Box

private struct OrderStatusBox: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                .foregroundColor(isSelected ? color : .secondary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OrderListView()
}
