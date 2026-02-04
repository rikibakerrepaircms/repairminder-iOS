# Stage 07: Orders Module

## Objective

Build the orders list and detail views, enabling staff to view, search, filter, and update repair orders.

---

## Dependencies

**Requires:** [See: Stage 06] complete - Dashboard and navigation established

---

## Complexity

**Medium** - CRUD operations, list/detail pattern

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Orders/OrderListView.swift` | Orders list with search/filter |
| `Features/Orders/OrderListViewModel.swift` | List business logic |
| `Features/Orders/OrderDetailView.swift` | Order detail screen |
| `Features/Orders/OrderDetailViewModel.swift` | Detail business logic |
| `Features/Orders/Components/OrderFilterSheet.swift` | Filter options |
| `Features/Orders/Components/OrderStatusBadge.swift` | Status display |
| `Features/Orders/Components/DeviceListItem.swift` | Device row in order |
| `Features/Orders/Components/PaymentSummary.swift` | Payment info display |

---

## Implementation Details

### 1. Order List View

```swift
// Features/Orders/OrderListView.swift
import SwiftUI

struct OrderListView: View {
    @StateObject private var viewModel = OrderListViewModel()
    @EnvironmentObject var router: AppRouter
    @State private var showFilter = false

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                if viewModel.orders.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Orders",
                        message: "No orders match your criteria"
                    )
                } else {
                    List {
                        ForEach(viewModel.orders) { order in
                            OrderListRow(order: order)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    router.navigate(to: .orderDetail(id: order.id))
                                }
                        }

                        if viewModel.hasMorePages {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .onAppear {
                                    Task { await viewModel.loadMore() }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Orders")
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .orderDetail(let id):
                    OrderDetailView(orderId: id)
                default:
                    EmptyView()
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search orders...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilter = true
                    } label: {
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showFilter) {
                OrderFilterSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadOrders()
            }
        }
    }
}

struct OrderListRow: View {
    let order: Order

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(order.displayRef)
                        .font(.headline)

                    OrderStatusBadge(status: order.status)
                }

                Text(order.clientName ?? order.clientEmail ?? "Unknown Client")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(order.deviceCount) device\(order.deviceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let total = order.total {
                    Text("£\(NSDecimalNumber(decimal: total).intValue)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(order.createdAt.formatted(as: .short))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### 2. Order List View Model

```swift
// Features/Orders/OrderListViewModel.swift
import Foundation
import Combine

@MainActor
final class OrderListViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var searchText: String = ""
    @Published var selectedStatus: OrderStatus?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var currentPage = 1
    private var totalPages = 1
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()

    var hasMorePages: Bool {
        currentPage < totalPages
    }

    var hasActiveFilters: Bool {
        selectedStatus != nil
    }

    init() {
        setupSearchDebounce()
    }

    func loadOrders() async {
        currentPage = 1
        isLoading = true

        do {
            let response: [Order] = try await APIClient.shared.request(
                .orders(
                    page: currentPage,
                    limit: pageSize,
                    status: selectedStatus?.rawValue,
                    search: searchText.isEmpty ? nil : searchText
                ),
                responseType: [Order].self
            )
            orders = response
            // Note: Would need pagination info from API response
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMorePages, !isLoading else { return }

        currentPage += 1

        do {
            let response: [Order] = try await APIClient.shared.request(
                .orders(
                    page: currentPage,
                    limit: pageSize,
                    status: selectedStatus?.rawValue,
                    search: searchText.isEmpty ? nil : searchText
                ),
                responseType: [Order].self
            )
            orders.append(contentsOf: response)
        } catch {
            currentPage -= 1
        }
    }

    func refresh() async {
        await loadOrders()
    }

    func applyFilter(status: OrderStatus?) {
        selectedStatus = status
        Task { await loadOrders() }
    }

    func clearFilters() {
        selectedStatus = nil
        Task { await loadOrders() }
    }

    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.loadOrders() }
            }
            .store(in: &cancellables)
    }
}
```

### 3. Order Detail View

```swift
// Features/Orders/OrderDetailView.swift
import SwiftUI

struct OrderDetailView: View {
    let orderId: String
    @StateObject private var viewModel: OrderDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(orderId: String) {
        self.orderId = orderId
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(orderId: orderId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let order = viewModel.order {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        OrderDetailHeader(order: order)

                        // Status Actions
                        if order.status.isActive {
                            StatusActionsView(
                                currentStatus: order.status,
                                onStatusChange: viewModel.updateStatus
                            )
                        }

                        // Client Info
                        ClientInfoCard(order: order)

                        // Devices
                        DevicesSection(
                            devices: viewModel.devices,
                            onDeviceTap: { device in
                                // Navigate to device detail
                            }
                        )

                        // Payment Summary
                        PaymentSummary(order: order)

                        // Notes
                        if let notes = order.notes, !notes.isEmpty {
                            NotesSection(notes: notes)
                        }
                    }
                    .padding()
                }
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    Task { await viewModel.loadOrder() }
                }
            }
        }
        .navigationTitle(viewModel.order?.displayRef ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadOrder()
        }
    }
}

struct OrderDetailHeader: View {
    let order: Order

    var body: some View {
        VStack(spacing: 8) {
            Text(order.displayRef)
                .font(.largeTitle)
                .fontWeight(.bold)

            OrderStatusBadge(status: order.status, size: .large)

            Text("Created \(order.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatusActionsView: View {
    let currentStatus: OrderStatus
    let onStatusChange: (OrderStatus) async -> Void

    var nextStatuses: [OrderStatus] {
        switch currentStatus {
        case .bookedIn:
            return [.inProgress]
        case .inProgress:
            return [.awaitingParts, .ready]
        case .awaitingParts:
            return [.inProgress]
        case .ready:
            return [.collected]
        default:
            return []
        }
    }

    var body: some View {
        if !nextStatuses.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Update Status")
                    .font(.headline)

                HStack {
                    ForEach(nextStatuses, id: \.self) { status in
                        Button {
                            Task { await onStatusChange(status) }
                        } label: {
                            Text(status.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ClientInfoCard: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Client", systemImage: "person.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                if let name = order.clientName {
                    Text(name)
                        .font(.subheadline)
                }
                if let email = order.clientEmail {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let phone = order.clientPhone {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DevicesSection: View {
    let devices: [Device]
    let onDeviceTap: (Device) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Devices (\(devices.count))", systemImage: "iphone")
                .font(.headline)

            ForEach(devices) { device in
                DeviceListItem(device: device)
                    .onTapGesture { onDeviceTap(device) }
            }
        }
    }
}

struct DeviceListItem: View {
    let device: Device

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let issue = device.issue {
                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                DeviceStatusBadge(status: device.status)

                if let price = device.price {
                    Text("£\(NSDecimalNumber(decimal: price).intValue)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DeviceStatusBadge: View {
    let status: DeviceStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .clipShape(Capsule())
    }

    var statusColor: Color {
        switch status {
        case .bookedIn, .diagnosing: return .blue
        case .awaitingApproval: return .yellow
        case .approved, .inRepair: return .orange
        case .awaitingParts: return .purple
        case .repaired, .qualityCheck, .ready: return .green
        case .collected: return .gray
        case .unrepairable: return .red
        }
    }
}

struct PaymentSummary: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Payment", systemImage: "creditcard")
                .font(.headline)

            VStack(spacing: 8) {
                if let total = order.total {
                    PaymentRow(label: "Total", value: "£\(NSDecimalNumber(decimal: total).intValue)")
                }
                if let deposit = order.deposit, deposit > 0 {
                    PaymentRow(label: "Deposit", value: "£\(NSDecimalNumber(decimal: deposit).intValue)")
                }
                if let balance = order.balance {
                    PaymentRow(label: "Balance", value: "£\(NSDecimalNumber(decimal: balance).intValue)", highlight: balance > 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PaymentRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(highlight ? .semibold : .regular)
                .foregroundStyle(highlight ? .primary : .secondary)
        }
        .font(.subheadline)
    }
}

struct NotesSection: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)

            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

### 4. Order Detail View Model

```swift
// Features/Orders/OrderDetailViewModel.swift
import Foundation

@MainActor
final class OrderDetailViewModel: ObservableObject {
    @Published var order: Order?
    @Published var devices: [Device] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let orderId: String
    private let syncEngine = SyncEngine.shared

    init(orderId: String) {
        self.orderId = orderId
    }

    func loadOrder() async {
        isLoading = true
        error = nil

        do {
            order = try await APIClient.shared.request(
                .order(id: orderId),
                responseType: Order.self
            )

            devices = try await APIClient.shared.request(
                .devices(orderId: orderId),
                responseType: [Device].self
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func updateStatus(_ newStatus: OrderStatus) async {
        guard let order = order else { return }

        struct StatusUpdate: Encodable {
            let status: String
        }

        do {
            try await APIClient.shared.requestVoid(
                .updateOrder(id: order.id, body: StatusUpdate(status: newStatus.rawValue))
            )

            self.order = Order(
                id: order.id,
                orderNumber: order.orderNumber,
                status: newStatus,
                total: order.total,
                deposit: order.deposit,
                balance: order.balance,
                notes: order.notes,
                clientId: order.clientId,
                clientName: order.clientName,
                clientEmail: order.clientEmail,
                clientPhone: order.clientPhone,
                locationId: order.locationId,
                locationName: order.locationName,
                assignedUserId: order.assignedUserId,
                assignedUserName: order.assignedUserName,
                deviceCount: order.deviceCount,
                createdAt: order.createdAt,
                updatedAt: Date()
            )

            syncEngine.queueChange(.orderUpdated(id: order.id))
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### 5. Order Status Badge

```swift
// Features/Orders/Components/OrderStatusBadge.swift
import SwiftUI

struct OrderStatusBadge: View {
    let status: OrderStatus
    var size: Size = .regular

    enum Size {
        case small, regular, large

        var font: Font {
            switch self {
            case .small: return .caption2
            case .regular: return .caption
            case .large: return .subheadline
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .regular: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            }
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(size.font)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(size.padding)
            .background(statusColor)
            .clipShape(Capsule())
    }

    var statusColor: Color {
        switch status {
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
    VStack {
        OrderStatusBadge(status: .bookedIn, size: .small)
        OrderStatusBadge(status: .inProgress, size: .regular)
        OrderStatusBadge(status: .ready, size: .large)
    }
}
```

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Orders list loads | Open orders tab | List populated |
| Search works | Type "john" | Filtered results |
| Filter by status | Select "In Progress" | Only in-progress orders |
| Pagination | Scroll to bottom | More orders load |
| Order detail loads | Tap order | Detail view shows |
| Status update | Tap "Ready" | Status changes, syncs |
| Pull to refresh | Pull down | List refreshes |
| Empty state | No matching orders | Empty message shown |

---

## Acceptance Checklist

- [ ] Orders list displays correctly
- [ ] Search filters orders
- [ ] Status filter works
- [ ] Pagination loads more
- [ ] Order detail shows all info
- [ ] Devices listed in order
- [ ] Payment summary accurate
- [ ] Status updates work
- [ ] Offline changes queued
- [ ] Navigation works correctly

---

## Handoff Notes

**For Stage 08:**
- Device model and status badge ready for reuse
- Same list/detail pattern applies
- Status update pattern established
