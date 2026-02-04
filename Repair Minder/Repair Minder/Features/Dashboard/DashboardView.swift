//
//  DashboardView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    private var currencySymbol: String {
        appState.currentCompany?.currencySymbol ?? "£"
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Group {
                if viewModel.isLoading && viewModel.stats == nil {
                    LoadingView(message: "Loading dashboard...")
                } else if let error = viewModel.error, viewModel.stats == nil {
                    ErrorView(error: error) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    dashboardContent
                }
            }
            .navigationTitle("Dashboard")
            .navigationDestination(for: AppRoute.self) { route in
                routeDestination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    UserAvatarButton(user: appState.currentUser)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadDashboard()
            }
        }
    }

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        switch route {
        case .devices:
            DeviceListView()
        case .deviceDetail(let id):
            DeviceDetailView(deviceId: id)
        case .orderDetail(let id):
            OrderDetailView(orderId: id)
        default:
            EmptyView()
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sync Status Banner
                SyncStatusBanner(
                    status: viewModel.syncStatus,
                    pendingCount: viewModel.pendingChangesCount
                )

                // Period Picker
                PeriodPicker(
                    selectedPeriod: $viewModel.selectedPeriod,
                    onChange: viewModel.changePeriod
                )
                .padding(.horizontal)

                // Stats Cards
                if let stats = viewModel.stats {
                    StatsGridView(stats: stats, currencySymbol: currencySymbol)
                } else if viewModel.isLoading {
                    StatsGridPlaceholder()
                }

                // Quick Actions
                QuickActionsView()
                    .padding(.horizontal)

                // My Queue
                if !viewModel.myQueue.isEmpty {
                    MyQueueSection(devices: viewModel.myQueue)
                }

                // Recent Orders
                if !viewModel.recentOrders.isEmpty {
                    RecentOrdersSection(orders: viewModel.recentOrders, currencySymbol: currencySymbol)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Stats Grid

struct StatsGridView: View {
    let stats: DashboardStats
    let currencySymbol: String

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Devices",
                value: "\(stats.devices.current.count)",
                change: stats.devices.comparisons.first?.changePercent,
                icon: "iphone",
                color: .blue
            )

            StatCard(
                title: "Revenue",
                value: "\(currencySymbol)\(formatRevenue(stats.revenue.current.total))",
                change: stats.revenue.comparisons.first?.changePercent,
                icon: "sterlingsign.circle",
                color: .green
            )

            StatCard(
                title: "Clients",
                value: "\(stats.clients.current.count)",
                change: stats.clients.comparisons.first?.changePercent,
                icon: "person.2",
                color: .purple
            )

            StatCard(
                title: "New Clients",
                value: "\(stats.newClients.current.count)",
                change: stats.newClients.comparisons.first?.changePercent,
                icon: "person.badge.plus",
                color: .orange
            )
        }
        .padding(.horizontal)
    }

    private func formatRevenue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

struct StatsGridPlaceholder: View {
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .frame(height: 100)
            }
        }
        .padding(.horizontal)
        .redacted(reason: .placeholder)
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .environment(AppRouter())
}
