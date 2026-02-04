# Stage 06: Staff Dashboard

## Objective

Build the main dashboard view for staff users, displaying key metrics, quick actions, and sync status indicator.

---

## Dependencies

**Requires:** [See: Stage 05] complete - Sync engine and repositories exist

---

## Complexity

**Medium** - UI implementation with data binding

---

## Files to Modify

| File | Changes |
|------|---------|
| `ContentView.swift` | Replace PlaceholderView for dashboard tab |

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Dashboard/DashboardView.swift` | Main dashboard screen |
| `Features/Dashboard/DashboardViewModel.swift` | Dashboard business logic |
| `Features/Dashboard/Components/StatCard.swift` | Metric display card |
| `Features/Dashboard/Components/QuickActionsView.swift` | Quick action buttons |
| `Features/Dashboard/Components/RecentOrdersView.swift` | Recent orders list |
| `Features/Dashboard/Components/SyncStatusBanner.swift` | Sync indicator |
| `Features/Dashboard/Components/PeriodPicker.swift` | Time period selector |
| `Shared/Components/ChangeIndicator.swift` | Percentage change display |

---

## Implementation Details

### 1. Dashboard View Model

```swift
// Features/Dashboard/DashboardViewModel.swift
import Foundation
import Combine
import os.log

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var stats: DashboardStats?
    @Published var recentOrders: [Order] = []
    @Published var myQueue: [Device] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var selectedPeriod: Period = .thisMonth

    private let syncEngine = SyncEngine.shared
    private let logger = Logger(subsystem: "com.mendmyi.repairminder", category: "Dashboard")
    private var cancellables = Set<AnyCancellable>()

    enum Period: String, CaseIterable {
        case today = "today"
        case thisWeek = "this_week"
        case thisMonth = "this_month"
        case lastMonth = "last_month"

        var displayName: String {
            switch self {
            case .today: return "Today"
            case .thisWeek: return "This Week"
            case .thisMonth: return "This Month"
            case .lastMonth: return "Last Month"
            }
        }
    }

    var syncStatus: SyncEngine.SyncStatus {
        syncEngine.status
    }

    var pendingChangesCount: Int {
        syncEngine.pendingChangesCount
    }

    init() {
        observeSyncStatus()
    }

    func loadDashboard() async {
        isLoading = true
        error = nil

        do {
            // Fetch stats from API
            stats = try await APIClient.shared.request(
                .dashboardStats(scope: "user", period: selectedPeriod.rawValue),
                responseType: DashboardStats.self
            )

            // Fetch recent orders
            let ordersResponse: [Order] = try await APIClient.shared.request(
                .orders(page: 1, limit: 5),
                responseType: [Order].self
            )
            recentOrders = ordersResponse

            // Fetch my queue
            let queueResponse: [Device] = try await APIClient.shared.request(
                .myQueue(page: 1, limit: 10),
                responseType: [Device].self
            )
            myQueue = queueResponse

            logger.debug("Dashboard loaded successfully")
        } catch {
            self.error = error.localizedDescription
            logger.error("Dashboard load failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func refresh() async {
        await loadDashboard()
    }

    func changePeriod(to period: Period) {
        selectedPeriod = period
        Task {
            await loadDashboard()
        }
    }

    private func observeSyncStatus() {
        syncEngine.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        syncEngine.$pendingChangesCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
```

### 2. Dashboard View

```swift
// Features/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
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
                        StatsGridView(stats: stats, companySymbol: appState.currentCompany?.currencySymbol ?? "£")
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
                        RecentOrdersSection(orders: viewModel.recentOrders)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
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
            .overlay {
                if let error = viewModel.error {
                    ErrorOverlay(message: error) {
                        Task { await viewModel.refresh() }
                    }
                }
            }
        }
    }
}

// MARK: - Stats Grid

struct StatsGridView: View {
    let stats: DashboardStats
    let companySymbol: String

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
                value: "\(companySymbol)\(Int(stats.revenue.current.total))",
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
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
```

### 3. Stat Card Component

```swift
// Features/Dashboard/Components/StatCard.swift
import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let change: Double?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()

                if let change = change {
                    ChangeIndicator(percentage: change)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    HStack {
        StatCard(
            title: "Revenue",
            value: "£12,450",
            change: 12.5,
            icon: "sterlingsign.circle",
            color: .green
        )

        StatCard(
            title: "Devices",
            value: "48",
            change: -5.2,
            icon: "iphone",
            color: .blue
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
```

### 4. Change Indicator

```swift
// Shared/Components/ChangeIndicator.swift
import SwiftUI

struct ChangeIndicator: View {
    let percentage: Double

    var isPositive: Bool {
        percentage >= 0
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)

            Text(String(format: "%.1f%%", abs(percentage)))
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(isPositive ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (isPositive ? Color.green : Color.red).opacity(0.15)
        )
        .clipShape(Capsule())
    }
}

#Preview {
    VStack {
        ChangeIndicator(percentage: 12.5)
        ChangeIndicator(percentage: -5.2)
        ChangeIndicator(percentage: 0)
    }
}
```

### 5. Quick Actions View

```swift
// Features/Dashboard/Components/QuickActionsView.swift
import SwiftUI

struct QuickActionsView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "New Order",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    // Navigate to create order
                    router.selectedTab = .orders
                }

                QuickActionButton(
                    title: "Scan",
                    icon: "qrcode.viewfinder",
                    color: .green
                ) {
                    router.selectedTab = .scanner
                }

                QuickActionButton(
                    title: "My Queue",
                    icon: "list.bullet.rectangle",
                    color: .orange
                ) {
                    router.selectedTab = .orders
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
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickActionsView()
        .environmentObject(AppRouter())
        .padding()
}
```

### 6. Recent Orders Section

```swift
// Features/Dashboard/Components/RecentOrdersView.swift
import SwiftUI

struct RecentOrdersSection: View {
    let orders: [Order]
    @EnvironmentObject var router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Orders")
                    .font(.headline)

                Spacer()

                Button("See All") {
                    router.selectedTab = .orders
                }
                .font(.subheadline)
            }
            .padding(.horizontal)

            LazyVStack(spacing: 0) {
                ForEach(orders) { order in
                    OrderRowView(order: order)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.navigate(to: .orderDetail(id: order.id))
                        }

                    if order.id != orders.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

struct OrderRowView: View {
    let order: Order

    var body: some View {
        HStack(spacing: 12) {
            // Order Number Badge
            Text(order.displayRef)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(order.clientName ?? order.clientEmail ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(order.deviceCount) device\(order.deviceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let total = order.total {
                    Text("£\(NSDecimalNumber(decimal: total).intValue)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(order.createdAt.relativeFormatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    var statusColor: Color {
        switch order.status {
        case .bookedIn: return .blue
        case .inProgress: return .orange
        case .awaitingParts: return .yellow
        case .ready: return .green
        case .collected: return .gray
        case .cancelled: return .red
        }
    }
}

#Preview {
    RecentOrdersSection(orders: [])
        .environmentObject(AppRouter())
}
```

### 7. Sync Status Banner

```swift
// Features/Dashboard/Components/SyncStatusBanner.swift
import SwiftUI

struct SyncStatusBanner: View {
    let status: SyncEngine.SyncStatus
    let pendingCount: Int

    var body: some View {
        Group {
            switch status {
            case .syncing(let progress):
                syncingBanner(progress: progress)
            case .offline:
                offlineBanner
            case .error(let message):
                errorBanner(message: message)
            case .idle, .completed:
                if pendingCount > 0 {
                    pendingBanner
                }
            }
        }
        .padding(.horizontal)
    }

    private func syncingBanner(progress: Double) -> some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)

            Text("Syncing...")
                .font(.subheadline)

            Spacer()

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var offlineBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)

            Text("You're offline")
                .font(.subheadline)

            Spacer()

            Text("Changes will sync when online")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)

            Text("Sync error")
                .font(.subheadline)

            Spacer()

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var pendingBanner: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)

            Text("\(pendingCount) pending change\(pendingCount == 1 ? "" : "s")")
                .font(.subheadline)

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack {
        SyncStatusBanner(status: .syncing(progress: 0.5), pendingCount: 0)
        SyncStatusBanner(status: .offline, pendingCount: 3)
        SyncStatusBanner(status: .error("Network timeout"), pendingCount: 0)
        SyncStatusBanner(status: .idle, pendingCount: 2)
    }
    .padding()
}
```

### 8. Period Picker

```swift
// Features/Dashboard/Components/PeriodPicker.swift
import SwiftUI

struct PeriodPicker: View {
    @Binding var selectedPeriod: DashboardViewModel.Period
    let onChange: (DashboardViewModel.Period) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DashboardViewModel.Period.allCases, id: \.self) { period in
                    PeriodChip(
                        title: period.displayName,
                        isSelected: selectedPeriod == period
                    ) {
                        selectedPeriod = period
                        onChange(period)
                    }
                }
            }
        }
    }
}

struct PeriodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PeriodPicker(
        selectedPeriod: .constant(.thisMonth),
        onChange: { _ in }
    )
    .padding()
}
```

### 9. User Avatar Button

```swift
// Shared/Components/UserAvatarButton.swift
import SwiftUI

struct UserAvatarButton: View {
    let user: User?
    @State private var showProfile = false

    var body: some View {
        Button {
            showProfile = true
        } label: {
            if let user = user {
                Text(user.initials)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle")
                    .font(.title2)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheetView(user: user)
        }
    }
}

struct ProfileSheetView: View {
    let user: User?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                if let user = user {
                    Section {
                        HStack {
                            Text(user.initials)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.accentColor)
                                .clipShape(Circle())

                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section {
                        LabeledContent("Role", value: user.role.displayName)
                        if let company = appState.currentCompany {
                            LabeledContent("Company", value: company.name)
                        }
                    }

                    Section {
                        Button("Sign Out", role: .destructive) {
                            Task {
                                await appState.logout()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UserAvatarButton(user: nil)
}
```

---

## Database Changes

None in this stage.

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Dashboard loads | Open dashboard tab | Stats cards populated |
| Period change | Select "Last Month" | Stats refresh with new data |
| Pull to refresh | Pull down | Data reloads |
| Offline indicator | Disconnect network | Offline banner shown |
| Pending changes | Have offline changes | Pending banner shown |
| Quick actions work | Tap "Scan" | Scanner tab selected |
| Order tap | Tap recent order | Navigates to order detail |
| User avatar | Tap avatar | Profile sheet opens |
| Logout | Tap Sign Out | Returns to login |

---

## Acceptance Checklist

- [ ] Dashboard displays 4 stat cards
- [ ] Stats show current values and change percentages
- [ ] Period picker switches between time ranges
- [ ] Quick actions navigate correctly
- [ ] Recent orders section shows 5 orders
- [ ] Sync status banner shows appropriate state
- [ ] Pull to refresh works
- [ ] Loading state shown while fetching
- [ ] Error state handled gracefully
- [ ] Profile sheet accessible and logout works

---

## Deployment

### Build Commands

```bash
xcodebuild -project "Repair Minder.xcodeproj" \
  -scheme "Repair Minder" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

### Verification

1. Login to app
2. Verify dashboard tab shows stats
3. Test period switching
4. Test pull to refresh
5. Test quick actions navigation
6. Test profile sheet and logout

---

## Handoff Notes

**For Stage 07:**
- `AppRouter.navigate(to: .orderDetail(id:))` pattern established
- Order row component can be reused in Orders list
- Quick actions pattern can be extended

**For Stage 13:**
- Logout functionality already in profile sheet
- Settings tab will add more options
