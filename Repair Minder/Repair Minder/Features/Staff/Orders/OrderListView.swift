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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterHeader
                mainContent
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
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        AnimatedSplitView(showDetail: selectedOrder != nil) {
            NavigationStack {
                VStack(spacing: 0) {
                    filterHeader
                    mainContent
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        filterButton
                    }
                }
                .sheet(isPresented: $showingFilters) {
                    OrderFilterSheet(viewModel: viewModel)
                }
            }
        } detail: {
            if let order = selectedOrder {
                NavigationStack {
                    OrderDetailView(orderId: order.id)
                }
                .id(order.id)
            }
        }
    }

    // MARK: - Shared Content

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.orders.isEmpty {
            loadingView
        } else if let error = viewModel.error, viewModel.orders.isEmpty {
            errorView(error)
        } else if viewModel.orders.isEmpty {
            emptyView
        } else if isRegularWidth {
            iPadOrdersList
        } else {
            iPhoneOrdersList
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

    // MARK: - iPhone Orders List

    private var iPhoneOrdersList: some View {
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
        .hidesBookingFABOnScroll()
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - iPad Orders List

    private var iPadOrdersList: some View {
        List {
            ForEach(viewModel.orders) { order in
                OrderRowView(order: order)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedOrder = order
                    }
                    .listRowBackground(
                        selectedOrder?.id == order.id
                            ? Color.accentColor.opacity(0.1)
                            : nil
                    )
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
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Subviews

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

// MARK: - Order Row View (iPhone - Compact)

struct OrderRowView: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row: order number + status
            HStack {
                Text(order.formattedOrderNumber)
                    .font(.subheadline.monospaced())
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                OrderStatusBadge(status: order.status)
            }

            // Payment + total
            HStack {
                PaymentStatusBadge(status: order.effectivePaymentStatus)

                Spacer()

                Text(CurrencyFormatter.format(order.displayTotal))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            // Client + location (stacked)
            VStack(alignment: .leading, spacing: 2) {
                Label(order.clientDisplayName, systemImage: "person.circle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let location = order.location {
                    Label(location.name, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // Assigned user + date
            HStack(spacing: 0) {
                if let assignedUser = order.assignedUser {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.shield.checkmark")
                            .foregroundColor(.green)
                        Text(assignedUser.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text(" · ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let date = order.formattedCreatedDate {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // Notes preview if available
            if let firstNote = order.notes?.first {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(firstNote.body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Order Row View (iPad - Wide)

struct OrderRowWideView: View {
    let order: Order

    var body: some View {
        HStack(spacing: 12) {
            Text(order.formattedOrderNumber)
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(order.clientDisplayName)
                .font(.subheadline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            OrderStatusBadge(status: order.status)

            PaymentStatusBadge(status: order.effectivePaymentStatus)

            if let date = order.formattedCreatedDate {
                Text(date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 70, alignment: .trailing)
            }

            Text(CurrencyFormatter.format(order.displayTotal))
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 6)
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
