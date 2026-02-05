//
//  ClientDetailView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

struct ClientDetailView: View {
    @StateObject private var viewModel: ClientDetailViewModel
    @State private var selectedOrderId: String?

    init(clientId: String) {
        _viewModel = StateObject(wrappedValue: ClientDetailViewModel(clientId: clientId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.client == nil {
                loadingView
            } else if let error = viewModel.error, viewModel.client == nil {
                errorView(error)
            } else if let client = viewModel.client {
                clientContent(client)
            }
        }
        .navigationTitle(viewModel.client?.displayName ?? "Client")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedOrderId) { orderId in
            OrderDetailView(orderId: orderId)
        }
        .task {
            await viewModel.loadClient()
        }
    }

    // MARK: - Content

    private func clientContent(_ client: Client) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                headerCard(client)

                // Contact section
                contactSection(client)

                // Stats section
                if let stats = client.stats {
                    statsSection(stats)
                }

                // Spend breakdown
                if let breakdown = client.stats?.spendBreakdown {
                    spendBreakdownSection(breakdown)
                }

                // Orders section
                if let orders = client.orders, !orders.isEmpty {
                    ordersSection(orders)
                }

                // Devices section
                if let devices = client.devices, !devices.isEmpty {
                    devicesSection(devices)
                }

                // Tickets section
                if let tickets = client.tickets, !tickets.isEmpty {
                    ticketsSection(tickets)
                }

                // Groups section
                if let groups = client.groups, !groups.isEmpty {
                    groupsSection(groups)
                }

                // Notes section
                if let notes = client.notes, !notes.isEmpty {
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

    private func headerCard(_ client: Client) -> some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))

                Text(client.initials)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 80, height: 80)

            // Name
            VStack(spacing: 4) {
                Text(client.displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                if let group = client.groupDisplayName {
                    Text(group)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // Status badges
            HStack(spacing: 8) {
                if client.isEmailSuppressed {
                    Label("Email Bounced", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }

                if client.marketingConsent == true {
                    Label("Marketing", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Contact Section

    private func contactSection(_ client: Client) -> some View {
        SectionCard(title: "Contact", icon: "person.text.rectangle") {
            VStack(spacing: 12) {
                contactRow(icon: "envelope", label: "Email", value: client.email)

                if let phone = client.phone, !phone.isEmpty {
                    contactRow(icon: "phone", label: "Phone", value: phone)
                }

                if let address = client.fullAddress {
                    contactRow(icon: "location", label: "Address", value: address)
                }
            }
        }
    }

    private func contactRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
            }

            Spacer()
        }
    }

    // MARK: - Stats Section

    private func statsSection(_ stats: ClientStats) -> some View {
        SectionCard(title: "Statistics", icon: "chart.bar") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statItem(value: "\(stats.orderCount)", label: "Orders", icon: "doc.text")
                statItem(value: "\(stats.deviceCount)", label: "Devices", icon: "iphone")
                statItem(value: stats.formattedTotalSpend, label: "Total Spend", icon: "sterlingsign.circle")
                statItem(value: stats.formattedAverageSpend, label: "Avg Order", icon: "chart.line.uptrend.xyaxis")
            }

            // Timing metrics
            if stats.authorizationCount ?? 0 > 0 || stats.collectionCount ?? 0 > 0 {
                Divider()
                    .padding(.vertical, 8)

                VStack(spacing: 8) {
                    if let avgAuth = stats.avgAuthorizationHours, stats.authorizationCount ?? 0 > 0 {
                        timingRow(label: "Avg time to approve", value: formatHours(avgAuth), count: stats.authorizationCount ?? 0)
                    }

                    if let avgCollection = stats.avgCollectionHours, stats.collectionCount ?? 0 > 0 {
                        timingRow(label: "Avg time to collect", value: formatHours(avgCollection), count: stats.collectionCount ?? 0)
                    }
                }
            }
        }
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func timingRow(label: String, value: String, count: Int) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)

            Text("(\(count))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60))m"
        } else if hours < 24 {
            return String(format: "%.1fh", hours)
        } else {
            let days = hours / 24
            return String(format: "%.1fd", days)
        }
    }

    // MARK: - Spend Breakdown Section

    private func spendBreakdownSection(_ breakdown: SpendBreakdown) -> some View {
        SectionCard(title: "Spend Breakdown", icon: "chart.pie") {
            VStack(spacing: 8) {
                if let repair = breakdown.repair, repair.count > 0 {
                    breakdownRow(label: "Repairs", count: repair.count, total: repair.formattedTotal, color: .blue)
                }
                if let deviceSale = breakdown.deviceSale, deviceSale.count > 0 {
                    breakdownRow(label: "Device Sales", count: deviceSale.count, total: deviceSale.formattedTotal, color: .green)
                }
                if let accessory = breakdown.accessory, accessory.count > 0 {
                    breakdownRow(label: "Accessories", count: accessory.count, total: accessory.formattedTotal, color: .orange)
                }
                if let buyback = breakdown.buyback, buyback.count > 0 {
                    breakdownRow(label: "Buyback", count: buyback.count, total: buyback.formattedTotal, color: .purple)
                }
            }
        }
    }

    private func breakdownRow(label: String, count: Int, total: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())

            Text(total)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Orders Section

    private func ordersSection(_ orders: [ClientOrder]) -> some View {
        SectionCard(title: "Recent Orders", icon: "doc.text") {
            VStack(spacing: 8) {
                ForEach(orders.prefix(5)) { order in
                    Button {
                        selectedOrderId = order.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(order.formattedNumber)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                if let status = order.orderStatus {
                                    Text(status.label)
                                        .font(.caption)
                                        .foregroundStyle(status.color)
                                }
                            }

                            Spacer()

                            Text(order.formattedTotal)
                                .font(.subheadline)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)

                    if order.id != orders.prefix(5).last?.id {
                        Divider()
                    }
                }

                if orders.count > 5 {
                    Text("+ \(orders.count - 5) more orders")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Devices Section

    private func devicesSection(_ devices: [ClientDevice]) -> some View {
        SectionCard(title: "Devices", icon: "iphone") {
            VStack(spacing: 8) {
                ForEach(devices.prefix(5)) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.displayName)
                                .font(.subheadline)

                            HStack(spacing: 8) {
                                Text(device.formattedOrderNumber)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let serial = device.serialNumber, !serial.isEmpty {
                                    Text(serial)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()

                        if let status = device.deviceStatus {
                            Text(status.label)
                                .font(.caption)
                                .foregroundStyle(status.color)
                        }
                    }
                    .padding(.vertical, 4)

                    if device.id != devices.prefix(5).last?.id {
                        Divider()
                    }
                }

                if devices.count > 5 {
                    Text("+ \(devices.count - 5) more devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Tickets Section

    private func ticketsSection(_ tickets: [ClientTicket]) -> some View {
        SectionCard(title: "Tickets", icon: "ticket") {
            VStack(spacing: 8) {
                ForEach(tickets.prefix(5)) { ticket in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ticket.subject ?? "No subject")
                                .font(.subheadline)
                                .lineLimit(1)

                            Text(ticket.formattedNumber)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let status = ticket.status {
                            Text(status.capitalized)
                                .font(.caption)
                                .foregroundStyle(status == "open" ? .green : .secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if ticket.id != tickets.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Groups Section

    private func groupsSection(_ groups: [ClientGroupMembership]) -> some View {
        SectionCard(title: "Groups", icon: "person.3") {
            FlowLayout(spacing: 8) {
                ForEach(groups) { group in
                    Text(group.name)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        SectionCard(title: "Notes", icon: "note.text") {
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Loading & Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading client...")
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
                    await viewModel.loadClient()
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, proposal: proposal).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, proposal: proposal).offsets

        for (subview, offset) in zip(subviews, offsets) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for size in sizes {
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            offsets.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (offsets, CGSize(width: maxX, height: currentY + rowHeight))
    }
}

#Preview {
    NavigationStack {
        ClientDetailView(clientId: "test")
    }
}
