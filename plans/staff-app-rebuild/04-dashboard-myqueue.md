# Stage 04: Dashboard & My Queue

## Objective

Implement the main dashboard with stats cards, period picker, and the user's assigned device queue.

## Dependencies

- **Requires**: Stage 03 complete (Authentication working)
- **Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/dashboard_handlers.js]`

## Complexity

**Medium** - Stats display, period picker, device queue list

## Files to Modify

| File | Changes |
|------|---------|
| `Features/Dashboard/DashboardView.swift` | Complete rewrite |
| `Features/Dashboard/DashboardViewModel.swift` | Complete rewrite |

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Dashboard/Components/StatCard.swift` | Individual stat display |
| `Features/Dashboard/Components/MyQueueSection.swift` | Assigned devices list |
| `Features/Dashboard/Components/QuickActionsView.swift` | Action buttons |
| `Features/Dashboard/Components/PeriodPicker.swift` | Period selection |

---

## Implementation Details

### DashboardViewModel.swift

```swift
// Features/Dashboard/DashboardViewModel.swift

import Foundation
import os.log

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var stats: DashboardStats?
    private(set) var myQueue: [Device] = []
    private(set) var isLoading = false
    private(set) var isLoadingQueue = false
    var error: String?

    var selectedPeriod: StatPeriod = .thisMonth

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "Dashboard")

    // MARK: - Load Data

    func loadDashboard() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadStats() }
            group.addTask { await self.loadMyQueue() }
        }
    }

    func loadStats() async {
        isLoading = true
        error = nil

        do {
            stats = try await APIClient.shared.request(
                .dashboardStats(scope: "user", period: selectedPeriod.rawValue),
                responseType: DashboardStats.self
            )
            logger.debug("Dashboard stats loaded")
        } catch {
            self.error = "Failed to load stats"
            logger.error("Stats error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func loadMyQueue() async {
        isLoadingQueue = true

        do {
            myQueue = try await APIClient.shared.request(
                .myQueue(page: 1, limit: 10),
                responseType: [Device].self
            )
            logger.debug("My queue loaded: \(self.myQueue.count) devices")
        } catch {
            logger.error("Queue error: \(error.localizedDescription)")
        }

        isLoadingQueue = false
    }

    func refresh() async {
        await loadDashboard()
        await AppState.shared.refreshHeaderCounts()
    }

    func changePeriod(to period: StatPeriod) async {
        selectedPeriod = period
        await loadStats()
    }
}

// MARK: - Stat Period

enum StatPeriod: String, CaseIterable, Identifiable {
    case today = "today"
    case yesterday = "yesterday"
    case thisWeek = "this_week"
    case lastWeek = "last_week"
    case thisMonth = "this_month"
    case lastMonth = "last_month"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        }
    }
}
```

---

### DashboardView.swift

```swift
// Features/Dashboard/DashboardView.swift

import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Picker
                    PeriodPicker(
                        selectedPeriod: viewModel.selectedPeriod,
                        onSelect: { period in
                            Task {
                                await viewModel.changePeriod(to: period)
                            }
                        }
                    )
                    .padding(.horizontal)

                    // Stats Cards
                    if viewModel.isLoading && viewModel.stats == nil {
                        ProgressView()
                            .frame(height: 200)
                    } else if let stats = viewModel.stats {
                        StatsGrid(stats: stats)
                            .padding(.horizontal)
                    }

                    // Quick Actions
                    QuickActionsView()
                        .padding(.horizontal)

                    // My Queue Section
                    MyQueueSection(
                        devices: viewModel.myQueue,
                        isLoading: viewModel.isLoadingQueue
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadDashboard()
            }
        }
    }
}

// MARK: - Stats Grid

struct StatsGrid: View {
    let stats: DashboardStats

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Devices",
                value: "\(stats.devices?.current.count ?? 0)",
                comparison: stats.devices?.comparisons?.first,
                icon: "iphone",
                color: .blue
            )

            StatCard(
                title: "Revenue",
                value: formatCurrency(stats.revenue?.current.total ?? 0),
                comparison: stats.revenue?.comparisons?.first,
                icon: "sterlingsign.circle",
                color: .green
            )

            StatCard(
                title: "Clients",
                value: "\(stats.clients?.current.count ?? 0)",
                comparison: stats.clients?.comparisons?.first,
                icon: "person.2",
                color: .purple
            )

            StatCard(
                title: "New Clients",
                value: "\(stats.newClients?.current.count ?? 0)",
                comparison: stats.newClients?.comparisons?.first,
                icon: "person.badge.plus",
                color: .orange
            )
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: NSNumber(value: value)) ?? "£0.00"
    }
}
```

---

### StatCard.swift

```swift
// Features/Dashboard/Components/StatCard.swift

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let comparison: StatComparison?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            if let comparison = comparison {
                ComparisonBadge(comparison: comparison)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

struct ComparisonBadge: View {
    let comparison: StatComparison

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)

            if let percent = comparison.changePercent {
                Text("\(abs(Int(percent)))%")
                    .font(.caption2)
            }

            Text("vs \(periodLabel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(isPositive ? .green : .red)
    }

    private var isPositive: Bool {
        (comparison.change ?? 0) >= 0
    }

    private var periodLabel: String {
        switch comparison.period {
        case "last_month": return "last month"
        case "last_week": return "last week"
        case "yesterday": return "yesterday"
        default: return comparison.period
        }
    }
}
```

---

### PeriodPicker.swift

```swift
// Features/Dashboard/Components/PeriodPicker.swift

import SwiftUI

struct PeriodPicker: View {
    let selectedPeriod: StatPeriod
    let onSelect: (StatPeriod) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatPeriod.allCases) { period in
                    Button {
                        onSelect(period)
                    } label: {
                        Text(period.displayName)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                period == selectedPeriod
                                    ? Color.accentColor
                                    : Color(.systemGray5)
                            )
                            .foregroundStyle(
                                period == selectedPeriod
                                    ? .white
                                    : .primary
                            )
                            .cornerRadius(16)
                    }
                }
            }
        }
    }
}
```

---

### MyQueueSection.swift

```swift
// Features/Dashboard/Components/MyQueueSection.swift

import SwiftUI

struct MyQueueSection: View {
    let devices: [Device]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Queue")
                    .font(.headline)

                Spacer()

                if !devices.isEmpty {
                    NavigationLink {
                        // Navigate to full device list filtered to my queue
                        DeviceListView(filterToMyQueue: true)
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                    }
                }
            }

            if isLoading && devices.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if devices.isEmpty {
                EmptyQueueView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(devices) { device in
                        NavigationLink {
                            DeviceDetailView(
                                orderId: device.orderId,
                                deviceId: device.id
                            )
                        } label: {
                            QueueDeviceRow(device: device)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct QueueDeviceRow: View {
    let device: Device

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let client = device.client {
                    Text(client.name ?? client.email ?? "Unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            DeviceStatusBadge(status: device.status)
        }
        .padding(.vertical, 8)
    }
}

struct EmptyQueueView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("Queue Empty")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("No devices assigned to you")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
```

---

### QuickActionsView.swift

```swift
// Features/Dashboard/Components/QuickActionsView.swift

import SwiftUI

struct QuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Scan",
                    icon: "qrcode.viewfinder",
                    color: .blue
                ) {
                    // Navigate to scanner
                }

                QuickActionButton(
                    title: "New Booking",
                    icon: "plus.circle",
                    color: .green
                ) {
                    // Navigate to booking wizard (separate feature)
                    // For now, show coming soon or placeholder
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .cornerRadius(12)
        }
    }
}
```

---

### DeviceStatusBadge.swift

```swift
// Shared/Components/DeviceStatusBadge.swift

import SwiftUI

struct DeviceStatusBadge: View {
    let status: DeviceStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .deviceReceived, .diagnosing:
            return .blue.opacity(0.2)
        case .readyToQuote, .awaitingAuthorisation:
            return .orange.opacity(0.2)
        case .repairing, .readyToRepair:
            return .purple.opacity(0.2)
        case .repairedQc, .rejectionQc:
            return .yellow.opacity(0.2)
        case .repairedReady, .rejectionReady:
            return .green.opacity(0.2)
        case .collected, .despatched:
            return .gray.opacity(0.2)
        case .rejected, .companyRejected:
            return .red.opacity(0.2)
        default:
            return .gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .deviceReceived, .diagnosing:
            return .blue
        case .readyToQuote, .awaitingAuthorisation:
            return .orange
        case .repairing, .readyToRepair:
            return .purple
        case .repairedQc, .rejectionQc:
            return .yellow.opacity(0.8)
        case .repairedReady, .rejectionReady:
            return .green
        case .collected, .despatched:
            return .gray
        case .rejected, .companyRejected:
            return .red
        default:
            return .gray
        }
    }
}
```

---

### MainTabView.swift

```swift
// App/MainTabView.swift

import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(AppState.Tab.dashboard)

            DeviceListView()
                .tabItem {
                    Label("Devices", systemImage: "iphone")
                }
                .badge(appState.headerCounts?.myQueue ?? 0)
                .tag(AppState.Tab.devices)

            OrderListView()
                .tabItem {
                    Label("Orders", systemImage: "doc.text.fill")
                }
                .tag(AppState.Tab.orders)

            EnquiryListView()
                .tabItem {
                    Label("Enquiries", systemImage: "message.fill")
                }
                .badge(appState.headerCounts?.openEnquiries ?? 0)
                .tag(AppState.Tab.enquiries)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppState.Tab.settings)
        }
    }
}
```

---

## Database Changes

None (iOS only)

## Test Cases

| Test | Steps | Expected |
|------|-------|----------|
| Dashboard loads | Navigate to dashboard | Stats display, no errors |
| Period change | Tap different period | Stats reload with new period |
| My Queue shows | Login with assigned devices | Devices appear in queue |
| Empty queue | Login with no assignments | Empty state shown |
| Pull to refresh | Pull down on dashboard | Data reloads |
| Tap queue item | Tap device in queue | Navigates to device detail |
| Stat comparison | View stats | Shows change vs previous period |
| Tab badges | View tab bar | Shows queue count on Devices tab |

## Acceptance Checklist

- [ ] Dashboard loads stats on appear
- [ ] Period picker changes stats
- [ ] All 6 period options work
- [ ] Stats cards show correct values
- [ ] Comparison badges show change direction
- [ ] My Queue section shows assigned devices
- [ ] Empty queue shows appropriate message
- [ ] Pull-to-refresh reloads all data
- [ ] Quick actions buttons are visible
- [ ] Tab bar shows correct badges
- [ ] No decode errors in console

## Deployment

1. Build and run
2. Login with test account
3. Verify stats display correctly
4. Change period and verify stats update
5. Check my queue shows assigned devices
6. Pull to refresh and verify reload
7. Verify tab badges show counts

## Handoff Notes

- Period picker persists in view model, not user defaults
- My Queue limited to 10 devices (see all navigates to full list)
- Quick Actions "New Booking" is placeholder for [Ref: plans/new-booking-feature/]
- DeviceStatusBadge reused in [See: Stage 05]
- [See: Stage 05] for DeviceListView and DeviceDetailView implementation
