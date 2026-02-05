//
//  DashboardView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Device Navigation

/// Navigation target for device detail
private struct DeviceNavigation: Hashable {
    let orderId: String
    let deviceId: String
}

// MARK: - Dashboard View

/// Main staff dashboard showing stats and active work
struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var showingPeriodPicker = false
    @State private var deviceNavigation: DeviceNavigation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period selector
                    periodSelector

                    // Active work banner (if any)
                    if viewModel.hasActiveWork {
                        activeWorkSection
                    }

                    // Main stats grid
                    statsSection

                    // Lifecycle comparison
                    if let comparison = viewModel.stats?.companyComparison {
                        lifecycleSection(comparison)
                    }

                    // Enquiry stats
                    if let enquiryStats = viewModel.enquiryStats {
                        enquirySection(enquiryStats)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    scopePicker
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadDashboard()
            }
            .overlay {
                if viewModel.isLoading && viewModel.stats == nil {
                    ProgressView()
                }
            }
            .navigationDestination(item: $deviceNavigation) { nav in
                DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)
            }
        }
    }

    // MARK: - Period Selector

    @ViewBuilder
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatPeriod.allCases) { period in
                    PeriodChip(
                        period: period,
                        isSelected: viewModel.selectedPeriod == period
                    ) {
                        Task {
                            await viewModel.setPeriod(period)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Scope Picker

    @ViewBuilder
    private var scopePicker: some View {
        Menu {
            ForEach(DashboardScope.allCases) { scope in
                Button {
                    Task {
                        await viewModel.setScope(scope)
                    }
                } label: {
                    if viewModel.selectedScope == scope {
                        Label(scope.displayName, systemImage: "checkmark")
                    } else {
                        Text(scope.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.selectedScope.displayName)
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(.blue)
        }
    }

    // MARK: - Active Work Section

    @ViewBuilder
    private var activeWorkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.orange)
                Text("In Progress")
                    .font(.headline)
                Spacer()
            }

            ForEach(viewModel.activeWork) { item in
                ActiveWorkRow(item: item) {
                    if let orderId = item.orderId {
                        deviceNavigation = DeviceNavigation(orderId: orderId, deviceId: item.id)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.headline)

            if let stats = viewModel.stats {
                StatGrid {
                    StatCard.deviceCount(
                        stats.devices.current.count,
                        change: viewModel.deviceComparison?.change,
                        changePercent: viewModel.deviceComparison?.changePercent
                    )

                    StatCard.revenue(
                        stats.revenue.current.total,
                        change: viewModel.revenueComparison?.change,
                        changePercent: viewModel.revenueComparison?.changePercent
                    )

                    StatCard.clients(
                        stats.clients.current.count,
                        change: viewModel.clientComparison?.change,
                        changePercent: viewModel.clientComparison?.changePercent
                    )

                    StatCard.clients(
                        stats.newClients.current.count,
                        title: "New Clients",
                        change: viewModel.newClientComparison?.change,
                        changePercent: viewModel.newClientComparison?.changePercent
                    )
                }
            } else {
                StatGrid {
                    StatCardPlaceholder()
                    StatCardPlaceholder()
                    StatCardPlaceholder()
                    StatCardPlaceholder()
                }
            }
        }
    }

    // MARK: - Lifecycle Section

    @ViewBuilder
    private func lifecycleSection(_ comparison: LifecycleComparison) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Turnaround Time")
                .font(.headline)

            HStack(spacing: 16) {
                // User average
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let hours = comparison.userAvgLifecycleHours {
                        Text(formatHours(hours))
                            .font(.title3.weight(.semibold))
                    } else {
                        Text("-")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
                    .frame(height: 40)

                // Company average
                VStack(alignment: .leading, spacing: 4) {
                    Text("Company Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let hours = comparison.companyAvgLifecycleHours {
                        Text(formatHours(hours))
                            .font(.title3.weight(.semibold))
                    } else {
                        Text("-")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Performance indicator
                if comparison.userAvgLifecycleHours != nil && comparison.companyAvgLifecycleHours != nil {
                    Text(comparison.performanceIndicator)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(
                            comparison.userAvgLifecycleHours! < comparison.companyAvgLifecycleHours!
                            ? .green : .orange
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (comparison.userAvgLifecycleHours! < comparison.companyAvgLifecycleHours!
                             ? Color.green : Color.orange).opacity(0.15)
                        )
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Enquiry Section

    @ViewBuilder
    private func enquirySection(_ stats: EnquiryStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enquiries")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                EnquiryStatCard(
                    title: "Leads",
                    value: stats.leads[viewModel.selectedPeriod],
                    icon: "envelope.badge"
                )

                EnquiryStatCard(
                    title: "First Replies",
                    value: stats.firstReplies[viewModel.selectedPeriod],
                    icon: "arrowshape.turn.up.left"
                )
            }

            // Response time comparison
            if let companyAvg = stats.companyAvgResponseMinutes,
               let userAvg = stats.userAvgResponseMinutes {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avg Response Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatMinutes(userAvg))
                            .font(.subheadline.weight(.medium))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Company Avg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatMinutes(companyAvg))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return String(format: "%.0f min", hours * 60)
        }
        if hours < 24 {
            return String(format: "%.1f hrs", hours)
        }
        let days = hours / 24
        return String(format: "%.1f days", days)
    }

    private func formatMinutes(_ minutes: Double) -> String {
        if minutes < 60 {
            return String(format: "%.0f min", minutes)
        }
        let hours = minutes / 60
        if hours < 24 {
            return String(format: "%.1f hrs", hours)
        }
        let days = hours / 24
        return String(format: "%.1f days", days)
    }
}

// MARK: - Supporting Views

/// Period selection chip
struct PeriodChip: View {
    let period: StatPeriod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(period.shortName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

/// Placeholder card while loading
struct StatCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 80, height: 12)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 60, height: 24)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 50, height: 10)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

/// Enquiry stat card
struct EnquiryStatCard: View {
    let title: String
    let value: PeriodValue
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            Text("\(value.count)")
                .font(.title2.weight(.bold))

            if let changePercent = value.changePercent {
                ChangeIndicator(
                    change: value.change.map { Double($0) },
                    changePercent: changePercent
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
}
