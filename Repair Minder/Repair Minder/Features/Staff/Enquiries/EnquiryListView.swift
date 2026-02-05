//
//  EnquiryListView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Main list view for support tickets/enquiries
struct EnquiryListView: View {
    @StateObject private var viewModel = EnquiryListViewModel()
    @State private var showingFilters = false
    @State private var showingSortOptions = false
    @State private var selectedTicket: Ticket?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Compact Filter Header
                filterHeader

                // Ticket List
                ticketList
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        sortMenu
                        Divider()
                        filterMenu
                    } label: {
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadTickets()
            }
            .navigationDestination(item: $selectedTicket) { ticket in
                EnquiryDetailView(ticketId: ticket.id)
            }
        }
    }

    // MARK: - Filter Header

    private var filterHeader: some View {
        VStack(spacing: 6) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search enquiries...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
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

            // Row 1: Type Filters (Lead / Order)
            HStack(spacing: 6) {
                TypeFilterBox(
                    title: "Leads",
                    icon: "person.badge.plus",
                    count: viewModel.ticketTypeCounts?.lead ?? 0,
                    isSelected: viewModel.selectedType == .lead,
                    color: .purple
                ) {
                    viewModel.setType(viewModel.selectedType == .lead ? nil : .lead)
                }

                TypeFilterBox(
                    title: "Orders",
                    icon: "doc.text",
                    count: viewModel.ticketTypeCounts?.order ?? 0,
                    isSelected: viewModel.selectedType == .order,
                    color: .blue
                ) {
                    viewModel.setType(viewModel.selectedType == .order ? nil : .order)
                }
            }

            // Row 2: Status Filters
            HStack(spacing: 4) {
                ForEach(TicketStatus.allCases, id: \.self) { status in
                    StatusFilterBox(
                        status: status,
                        count: countFor(status: status),
                        isSelected: viewModel.selectedStatus == status
                    ) {
                        viewModel.setStatus(viewModel.selectedStatus == status ? nil : status)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGroupedBackground))
    }

    private func countFor(status: TicketStatus) -> Int {
        guard let counts = viewModel.statusCounts else { return 0 }
        switch status {
        case .open: return counts.open
        case .pending: return counts.pending
        case .resolved: return counts.resolved
        case .closed: return counts.closed
        }
    }

    // MARK: - Ticket List

    @ViewBuilder
    private var ticketList: some View {
        if viewModel.isLoading && viewModel.tickets.isEmpty {
            loadingView
        } else if let error = viewModel.error {
            errorView(error)
        } else if viewModel.tickets.isEmpty {
            emptyView
        } else {
            List {
                ForEach(viewModel.tickets) { ticket in
                    TicketRow(ticket: ticket)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTicket = ticket
                        }
                        .task {
                            await viewModel.loadMoreIfNeeded(currentTicket: ticket)
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
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text("Loading enquiries...")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Failed to load enquiries")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "envelope.open")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No enquiries")
                .font(.headline)
            Text("There are no enquiries matching your filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if viewModel.hasActiveFilters {
                Button("Clear Filters") {
                    viewModel.clearFilters()
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Menus

    private var sortMenu: some View {
        Menu("Sort By") {
            ForEach(EnquiryListViewModel.SortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.setSorting(by: option, order: viewModel.sortOrder)
                } label: {
                    HStack {
                        Text(option.label)
                        if viewModel.sortBy == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            ForEach(EnquiryListViewModel.SortOrder.allCases, id: \.self) { order in
                Button {
                    viewModel.setSorting(by: viewModel.sortBy, order: order)
                } label: {
                    HStack {
                        Text(order.label)
                        if viewModel.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var filterMenu: some View {
        // Type filter
        Menu("Type") {
            Button("All Types") {
                viewModel.setType(nil)
            }
            ForEach(TicketType.allCases, id: \.self) { type in
                Button {
                    viewModel.setType(type)
                } label: {
                    HStack {
                        Label(type.label, systemImage: type.icon)
                        if viewModel.selectedType == type {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        // Location filter
        if !viewModel.companyLocations.isEmpty {
            Menu("Location") {
                Button("All Locations") {
                    viewModel.setLocation(nil)
                }
                Button("Unassigned") {
                    viewModel.setLocation("unset")
                }
                Divider()
                ForEach(viewModel.companyLocations) { location in
                    Button {
                        viewModel.setLocation(location.id)
                    } label: {
                        HStack {
                            Text(location.name)
                            if viewModel.selectedLocationId == location.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }

        // Workflow status filter
        Menu("Workflow") {
            ForEach(WorkflowStatusFilter.allCases, id: \.self) { status in
                Button {
                    viewModel.setWorkflowStatus(status == .all ? nil : status)
                } label: {
                    HStack {
                        Text(status.label)
                        if (viewModel.selectedWorkflowStatus == status) ||
                           (viewModel.selectedWorkflowStatus == nil && status == .all) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        if viewModel.hasActiveFilters {
            Divider()
            Button(role: .destructive) {
                viewModel.clearFilters()
            } label: {
                Label("Clear Filters", systemImage: "xmark.circle")
            }
        }
    }
}

// MARK: - Type Filter Box

private struct TypeFilterBox: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                Spacer()
                Text("\(count)")
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? color : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Filter Box

private struct StatusFilterBox: View {
    let status: TicketStatus
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text("\(count)")
                    .font(.caption.bold())
                Text(status.shortLabel)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? status.color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? status.color : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? status.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ticket Row

private struct TicketRow: View {
    let ticket: Ticket

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Text(ticket.displayNumber)
                    .font(.subheadline.monospaced())
                    .foregroundColor(.secondary)

                TypeBadge(type: ticket.ticketType)

                Text("·")
                    .foregroundColor(.secondary)
                Text(ticket.formattedLastUpdate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: ticket.status.icon)
                    Text(ticket.status.label)
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ticket.status.color.opacity(0.15))
                .foregroundColor(ticket.status.color)
                .clipShape(Capsule())
            }

            // Subject
            Text(ticket.subject)
                .font(.headline)
                .lineLimit(2)

            // Client info
            HStack(spacing: 4) {
                Image(systemName: "person.circle")
                    .foregroundColor(.secondary)
                Text(ticket.client.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let location = ticket.location {
                    Text("•")
                        .foregroundColor(.secondary)
                    Image(systemName: "mappin")
                        .foregroundColor(.secondary)
                    Text(location.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Order info if present
            if let order = ticket.order {
                HStack(spacing: 8) {
                    Label("\(order.deviceCount) device\(order.deviceCount == 1 ? "" : "s")", systemImage: "iphone")
                        .font(.caption)
                        .foregroundColor(.blue)

                    Text(order.status.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }

            // Assigned user
            if let assignedUser = ticket.assignedUser {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .foregroundColor(.green)
                    Text("Assigned to \(assignedUser.fullName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Notes preview
            if let notes = ticket.notes, let firstNote = notes.first {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "note.text")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(firstNote.body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Type Badge

private struct TypeBadge: View {
    let type: TicketType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
            Text(type.shortLabel)
        }
        .font(.caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(type.color.opacity(0.15))
        .foregroundColor(type.color)
        .clipShape(Capsule())
    }
}

#Preview {
    EnquiryListView()
}
