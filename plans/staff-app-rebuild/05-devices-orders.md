# Stage 05: Devices & Orders

## Objective

Implement device list, device detail with actions, order list, and order detail views.

## Dependencies

- **Requires**: Stage 03 complete (Authentication)
- **Requires**: Stage 04 complete (DeviceStatusBadge component)
- **Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/device_handlers.js]`
- **Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/order_handlers.js]`

## Complexity

**High** - Multiple views, device actions, status transitions

## Files to Modify

| File | Changes |
|------|---------|
| `Features/Devices/DeviceListView.swift` | Complete rewrite |
| `Features/Devices/DeviceDetailView.swift` | Complete rewrite |
| `Features/Orders/OrderListView.swift` | Complete rewrite |
| `Features/Orders/OrderDetailView.swift` | Complete rewrite |

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Devices/DeviceListViewModel.swift` | Device list logic |
| `Features/Devices/DeviceDetailViewModel.swift` | Device detail and actions |
| `Features/Devices/Components/DeviceListRow.swift` | Device row component |
| `Features/Devices/Components/DeviceHeaderCard.swift` | Device header info |
| `Features/Devices/Components/DeviceActionsSheet.swift` | Status actions |
| `Features/Orders/OrderListViewModel.swift` | Order list logic |
| `Features/Orders/OrderDetailViewModel.swift` | Order detail logic |
| `Features/Orders/Components/OrderListRow.swift` | Order row component |
| `Features/Orders/Components/OrderDevicesSection.swift` | Devices in order |

---

## Implementation Details

### DeviceListViewModel.swift

```swift
// Features/Devices/DeviceListViewModel.swift

import Foundation
import os.log

@MainActor
@Observable
final class DeviceListViewModel {
    private(set) var devices: [Device] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMorePages = true
    var error: String?

    var selectedStatus: DeviceStatus?
    var searchText = ""
    var filterToMyQueue = false

    private var currentPage = 1
    private let pageSize = 20
    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "Devices")

    // MARK: - Load Devices

    func loadDevices(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMorePages = true
        }

        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let endpoint: APIEndpoint
            if filterToMyQueue {
                endpoint = .myQueue(page: currentPage, limit: pageSize)
            } else {
                endpoint = .devices(
                    page: currentPage,
                    limit: pageSize,
                    status: selectedStatus?.rawValue
                )
            }

            let newDevices = try await APIClient.shared.request(
                endpoint,
                responseType: [Device].self
            )

            if refresh {
                devices = newDevices
            } else {
                devices.append(contentsOf: newDevices)
            }

            hasMorePages = newDevices.count == pageSize
            currentPage += 1

            logger.debug("Loaded \(newDevices.count) devices, total: \(self.devices.count)")
        } catch {
            self.error = "Failed to load devices"
            logger.error("Load error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore && hasMorePages else { return }
        isLoadingMore = true
        await loadDevices()
        isLoadingMore = false
    }

    func refresh() async {
        await loadDevices(refresh: true)
    }

    func applyStatusFilter(_ status: DeviceStatus?) async {
        selectedStatus = status
        await loadDevices(refresh: true)
    }

    func search(_ text: String) async {
        searchText = text
        // For now, filter locally
        // TODO: Implement server-side search
    }
}
```

---

### DeviceListView.swift

```swift
// Features/Devices/DeviceListView.swift

import SwiftUI

struct DeviceListView: View {
    var filterToMyQueue: Bool = false

    @State private var viewModel = DeviceListViewModel()
    @State private var showStatusFilter = false

    var body: some View {
        NavigationStack {
            List {
                // Status Filter Chips
                if !filterToMyQueue {
                    StatusFilterChips(
                        selectedStatus: viewModel.selectedStatus,
                        onSelect: { status in
                            Task {
                                await viewModel.applyStatusFilter(status)
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Device List
                ForEach(viewModel.devices) { device in
                    NavigationLink {
                        DeviceDetailView(
                            orderId: device.orderId,
                            deviceId: device.id
                        )
                    } label: {
                        DeviceListRow(device: device)
                    }
                    .onAppear {
                        // Load more when reaching end
                        if device == viewModel.devices.last {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }

                // Loading indicator
                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle(filterToMyQueue ? "My Queue" : "Devices")
            .searchable(text: $viewModel.searchText, prompt: "Search devices...")
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.devices.isEmpty {
                    ProgressView()
                } else if viewModel.devices.isEmpty {
                    ContentUnavailableView(
                        "No Devices",
                        systemImage: "iphone.slash",
                        description: Text(filterToMyQueue ? "No devices assigned to you" : "No devices found")
                    )
                }
            }
            .task {
                viewModel.filterToMyQueue = filterToMyQueue
                await viewModel.loadDevices(refresh: true)
            }
        }
    }
}

// MARK: - Status Filter Chips

struct StatusFilterChips: View {
    let selectedStatus: DeviceStatus?
    let onSelect: (DeviceStatus?) -> Void

    private let statuses: [DeviceStatus] = [
        .diagnosing, .awaitingAuthorisation, .repairing,
        .repairedReady, .awaitingCollection
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selectedStatus == nil,
                    action: { onSelect(nil) }
                )

                ForEach(statuses, id: \.self) { status in
                    FilterChip(
                        title: status.displayName,
                        isSelected: selectedStatus == status,
                        action: { onSelect(status) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}
```

---

### DeviceListRow.swift

```swift
// Features/Devices/Components/DeviceListRow.swift

import SwiftUI

struct DeviceListRow: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(device.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                DeviceStatusBadge(status: device.status)
            }

            HStack {
                if let orderNumber = device.orderNumber {
                    Text("#\(orderNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let client = device.client {
                    Text(client.name ?? client.email ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let engineer = device.assignedEngineer {
                    Label(engineer.name, systemImage: "person.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

---

### DeviceDetailViewModel.swift

```swift
// Features/Devices/DeviceDetailViewModel.swift

import Foundation
import os.log

@MainActor
@Observable
final class DeviceDetailViewModel {
    let orderId: String
    let deviceId: String

    private(set) var device: Device?
    private(set) var isLoading = false
    private(set) var isExecutingAction = false
    var error: String?
    var successMessage: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "DeviceDetail")

    init(orderId: String, deviceId: String) {
        self.orderId = orderId
        self.deviceId = deviceId
    }

    // MARK: - Load

    func loadDevice() async {
        isLoading = true
        error = nil

        do {
            device = try await APIClient.shared.request(
                .device(orderId: orderId, deviceId: deviceId),
                responseType: Device.self
            )
            logger.debug("Device loaded: \(self.device?.displayName ?? "unknown")")
        } catch {
            self.error = "Failed to load device"
            logger.error("Load error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Actions

    func executeAction(_ action: String, notes: String? = nil) async {
        isExecutingAction = true
        error = nil
        successMessage = nil

        do {
            try await APIClient.shared.requestVoid(
                .deviceAction(deviceId: deviceId, action: action, notes: notes)
            )
            successMessage = "Action completed"
            await loadDevice() // Reload to get new status
        } catch {
            self.error = "Failed to execute action"
            logger.error("Action error: \(error.localizedDescription)")
        }

        isExecutingAction = false
    }

    func assignEngineer(_ engineerId: String) async {
        isExecutingAction = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(
                .assignEngineer(deviceId: deviceId, engineerId: engineerId)
            )
            successMessage = "Engineer assigned"
            await loadDevice()
        } catch {
            self.error = "Failed to assign engineer"
        }

        isExecutingAction = false
    }

    // MARK: - Available Actions

    var availableActions: [DeviceAction] {
        guard let device = device else { return [] }

        // Based on current status, return available actions
        switch device.status {
        case .deviceReceived:
            return [.startDiagnosis]
        case .diagnosing:
            return [.completeDiagnosis]
        case .readyToQuote:
            return [.sendQuote]
        case .awaitingAuthorisation:
            return [] // Customer action
        case .authorisedSourceParts, .authorisedAwaitingParts:
            return [.startRepair]
        case .readyToRepair:
            return [.startRepair]
        case .repairing:
            return [.completeRepair]
        case .repairedQc:
            return [.passQc, .failQc]
        case .repairedReady, .rejectionReady:
            return [.markReady]
        default:
            return []
        }
    }
}

// MARK: - Device Actions

enum DeviceAction: String, CaseIterable {
    case startDiagnosis = "start_diagnosis"
    case completeDiagnosis = "complete_diagnosis"
    case sendQuote = "send_quote"
    case startRepair = "start_repair"
    case completeRepair = "complete_repair"
    case passQc = "pass_qc"
    case failQc = "fail_qc"
    case markReady = "mark_ready"
    case collect = "collect"
    case despatch = "despatch"

    var displayName: String {
        switch self {
        case .startDiagnosis: return "Start Diagnosis"
        case .completeDiagnosis: return "Complete Diagnosis"
        case .sendQuote: return "Send Quote"
        case .startRepair: return "Start Repair"
        case .completeRepair: return "Complete Repair"
        case .passQc: return "Pass QC"
        case .failQc: return "Fail QC"
        case .markReady: return "Mark Ready"
        case .collect: return "Mark Collected"
        case .despatch: return "Mark Despatched"
        }
    }

    var icon: String {
        switch self {
        case .startDiagnosis: return "magnifyingglass"
        case .completeDiagnosis: return "checkmark.circle"
        case .sendQuote: return "paperplane"
        case .startRepair: return "wrench.and.screwdriver"
        case .completeRepair: return "checkmark.circle"
        case .passQc: return "checkmark.seal"
        case .failQc: return "xmark.seal"
        case .markReady: return "bell"
        case .collect: return "hand.raised"
        case .despatch: return "shippingbox"
        }
    }
}
```

---

### DeviceDetailView.swift

```swift
// Features/Devices/DeviceDetailView.swift

import SwiftUI

struct DeviceDetailView: View {
    let orderId: String
    let deviceId: String

    @State private var viewModel: DeviceDetailViewModel
    @State private var showActionsSheet = false

    init(orderId: String, deviceId: String) {
        self.orderId = orderId
        self.deviceId = deviceId
        _viewModel = State(initialValue: DeviceDetailViewModel(orderId: orderId, deviceId: deviceId))
    }

    var body: some View {
        ScrollView {
            if let device = viewModel.device {
                VStack(spacing: 16) {
                    DeviceHeaderCard(device: device)

                    DeviceInfoSection(device: device)

                    if let notes = device.customerReportedIssues, !notes.isEmpty {
                        NotesCard(title: "Customer Reported Issues", notes: notes)
                    }

                    if let notes = device.diagnosisNotes, !notes.isEmpty {
                        NotesCard(title: "Diagnosis Notes", notes: notes)
                    }

                    if let notes = device.repairNotes, !notes.isEmpty {
                        NotesCard(title: "Repair Notes", notes: notes)
                    }

                    // Actions
                    if !viewModel.availableActions.isEmpty {
                        ActionsSection(
                            actions: viewModel.availableActions,
                            isExecuting: viewModel.isExecutingAction,
                            onAction: { action in
                                Task {
                                    await viewModel.executeAction(action.rawValue)
                                }
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.device?.displayName ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        // Navigate to order
                    } label: {
                        Label("View Order", systemImage: "doc.text")
                    }

                    Button {
                        // Assign engineer
                    } label: {
                        Label("Assign Engineer", systemImage: "person.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.device == nil {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .task {
            await viewModel.loadDevice()
        }
    }
}

// MARK: - Device Header Card

struct DeviceHeaderCard: View {
    let device: Device

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let serial = device.serialNumber {
                        Text("S/N: \(serial)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let imei = device.imei {
                        Text("IMEI: \(imei)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                DeviceStatusBadge(status: device.status)
            }

            Divider()

            HStack {
                if let engineer = device.assignedEngineer {
                    Label(engineer.name, systemImage: "person.circle")
                        .font(.caption)
                } else {
                    Label("Unassigned", systemImage: "person.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let workflow = device.workflowType {
                    Text(workflow.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Device Info Section

struct DeviceInfoSection: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Info")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InfoItem(label: "Colour", value: device.colour)
                InfoItem(label: "Storage", value: device.storageCapacity)
                InfoItem(label: "Condition", value: device.conditionGrade)
                InfoItem(label: "Find My", value: device.findMyStatus)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct InfoItem: View {
    let label: String
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.subheadline)
        }
    }
}

// MARK: - Notes Card

struct NotesCard: View {
    let title: String
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Actions Section

struct ActionsSection: View {
    let actions: [DeviceAction]
    let isExecuting: Bool
    let onAction: (DeviceAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)

            ForEach(actions, id: \.self) { action in
                Button {
                    onAction(action)
                } label: {
                    HStack {
                        Image(systemName: action.icon)
                        Text(action.displayName)
                        Spacer()
                        if isExecuting {
                            ProgressView()
                        }
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(isExecuting)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
```

---

### OrderListViewModel.swift

```swift
// Features/Orders/OrderListViewModel.swift

import Foundation

@MainActor
@Observable
final class OrderListViewModel {
    private(set) var orders: [Order] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMorePages = true
    var error: String?

    var selectedStatus: OrderStatus?
    var searchText = ""

    private var currentPage = 1
    private let pageSize = 20

    func loadOrders(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMorePages = true
        }

        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let newOrders = try await APIClient.shared.request(
                .orders(
                    page: currentPage,
                    limit: pageSize,
                    status: selectedStatus?.rawValue,
                    search: searchText.isEmpty ? nil : searchText
                ),
                responseType: [Order].self
            )

            if refresh {
                orders = newOrders
            } else {
                orders.append(contentsOf: newOrders)
            }

            hasMorePages = newOrders.count == pageSize
            currentPage += 1
        } catch {
            self.error = "Failed to load orders"
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore && hasMorePages else { return }
        isLoadingMore = true
        await loadOrders()
        isLoadingMore = false
    }

    func refresh() async {
        await loadOrders(refresh: true)
    }

    func applyStatusFilter(_ status: OrderStatus?) async {
        selectedStatus = status
        await loadOrders(refresh: true)
    }
}
```

---

### OrderListView.swift

```swift
// Features/Orders/OrderListView.swift

import SwiftUI

struct OrderListView: View {
    @State private var viewModel = OrderListViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Status Filter
                OrderStatusFilter(
                    selectedStatus: viewModel.selectedStatus,
                    onSelect: { status in
                        Task {
                            await viewModel.applyStatusFilter(status)
                        }
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Orders
                ForEach(viewModel.orders) { order in
                    NavigationLink {
                        OrderDetailView(orderId: order.id)
                    } label: {
                        OrderListRow(order: order)
                    }
                    .onAppear {
                        if order == viewModel.orders.last {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Orders")
            .searchable(text: $viewModel.searchText, prompt: "Search orders...")
            .onSubmit(of: .search) {
                Task { await viewModel.loadOrders(refresh: true) }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    ProgressView()
                }
            }
            .task {
                await viewModel.loadOrders(refresh: true)
            }
        }
    }
}

struct OrderStatusFilter: View {
    let selectedStatus: OrderStatus?
    let onSelect: (OrderStatus?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedStatus == nil) {
                    onSelect(nil)
                }

                ForEach(OrderStatus.allCases.filter { $0 != .unknown }, id: \.self) { status in
                    FilterChip(title: status.displayName, isSelected: selectedStatus == status) {
                        onSelect(status)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
```

---

### OrderListRow.swift

```swift
// Features/Orders/Components/OrderListRow.swift

import SwiftUI

struct OrderListRow: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.displayRef)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                OrderStatusBadge(status: order.status)
            }

            HStack {
                Text(order.client.fullName)
                    .font(.subheadline)

                Spacer()

                if let total = order.orderTotal {
                    Text(formatCurrency(total))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            HStack {
                if let deviceCount = order.deviceCount {
                    Label("\(deviceCount) device\(deviceCount == 1 ? "" : "s")", systemImage: "iphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(order.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: NSNumber(value: value)) ?? "£0.00"
    }
}

struct OrderStatusBadge: View {
    let status: OrderStatus

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
        case .awaitingDevice: return .orange.opacity(0.2)
        case .inProgress: return .blue.opacity(0.2)
        case .serviceComplete: return .purple.opacity(0.2)
        case .awaitingCollection: return .green.opacity(0.2)
        case .collectedDespatched: return .gray.opacity(0.2)
        case .unknown: return .gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .awaitingDevice: return .orange
        case .inProgress: return .blue
        case .serviceComplete: return .purple
        case .awaitingCollection: return .green
        case .collectedDespatched: return .gray
        case .unknown: return .gray
        }
    }
}
```

---

### OrderDetailView.swift

```swift
// Features/Orders/OrderDetailView.swift

import SwiftUI

struct OrderDetailView: View {
    let orderId: String
    @State private var viewModel: OrderDetailViewModel

    init(orderId: String) {
        self.orderId = orderId
        _viewModel = State(initialValue: OrderDetailViewModel(orderId: orderId))
    }

    var body: some View {
        ScrollView {
            if let order = viewModel.order {
                VStack(spacing: 16) {
                    // Header
                    OrderHeaderCard(order: order)

                    // Client Info
                    ClientInfoCard(client: order.client)

                    // Devices
                    if let devices = order.devices, !devices.isEmpty {
                        OrderDevicesSection(devices: devices, orderId: orderId)
                    }

                    // Totals
                    if let totals = order.totals {
                        OrderTotalsCard(totals: totals, paymentStatus: order.paymentStatus)
                    }

                    // Notes
                    if let notes = order.notes, !notes.isEmpty {
                        OrderNotesSection(notes: notes)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.order?.displayRef ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading && viewModel.order == nil {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.loadOrder()
        }
        .task {
            await viewModel.loadOrder()
        }
    }
}

// MARK: - Order Header Card

struct OrderHeaderCard: View {
    let order: Order

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(order.displayRef)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                OrderStatusBadge(status: order.status)
            }

            HStack {
                if let location = order.location {
                    Label(location.name, systemImage: "mappin")
                        .font(.caption)
                }

                Spacer()

                Text(order.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Client Info Card

struct ClientInfoCard: View {
    let client: OrderClient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Client")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(client.fullName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let email = client.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let phone = client.phone {
                        Text(phone)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Contact actions
                HStack(spacing: 12) {
                    if let phone = client.phone {
                        Button {
                            if let url = URL(string: "tel:\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "phone.circle.fill")
                                .font(.title2)
                        }
                    }

                    if let email = client.email {
                        Button {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "envelope.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Order Devices Section

struct OrderDevicesSection: View {
    let devices: [OrderDevice]
    let orderId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Devices")
                .font(.headline)

            ForEach(devices) { device in
                NavigationLink {
                    DeviceDetailView(orderId: orderId, deviceId: device.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.displayName ?? "Unknown Device")
                                .font(.subheadline)
                        }

                        Spacer()

                        if let status = device.status {
                            DeviceStatusBadge(status: status)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Order Totals Card

struct OrderTotalsCard: View {
    let totals: OrderTotals
    let paymentStatus: PaymentStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Payment")
                    .font(.headline)

                Spacer()

                if let status = paymentStatus {
                    PaymentStatusBadge(status: status)
                }
            }

            VStack(spacing: 8) {
                TotalRow(label: "Subtotal", value: totals.subtotal)
                TotalRow(label: "VAT", value: totals.vatTotal)
                Divider()
                TotalRow(label: "Total", value: totals.grandTotal, bold: true)

                if let paid = totals.amountPaid, paid > 0 {
                    TotalRow(label: "Paid", value: paid, color: .green)
                }

                if let due = totals.balanceDue, due > 0 {
                    TotalRow(label: "Balance Due", value: due, bold: true, color: .orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct TotalRow: View {
    let label: String
    let value: Double
    var bold: Bool = false
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.bold() : .subheadline)
            Spacer()
            Text(formatCurrency(value))
                .font(bold ? .subheadline.bold() : .subheadline)
                .foregroundStyle(color)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: NSNumber(value: value)) ?? "£0.00"
    }
}

struct PaymentStatusBadge: View {
    let status: PaymentStatus

    var body: some View {
        Text(status.rawValue.capitalized)
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
        case .unpaid: return .red.opacity(0.2)
        case .partial: return .orange.opacity(0.2)
        case .paid: return .green.opacity(0.2)
        case .unknown: return .gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .unpaid: return .red
        case .partial: return .orange
        case .paid: return .green
        case .unknown: return .gray
        }
    }
}
```

---

### OrderDetailViewModel.swift

```swift
// Features/Orders/OrderDetailViewModel.swift

import Foundation

@MainActor
@Observable
final class OrderDetailViewModel {
    let orderId: String

    private(set) var order: Order?
    private(set) var isLoading = false
    var error: String?

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
        } catch {
            self.error = "Failed to load order"
        }

        isLoading = false
    }
}
```

---

## Database Changes

None (iOS only)

## Test Cases

| Test | Steps | Expected |
|------|-------|----------|
| Device list loads | Navigate to Devices tab | List displays |
| Device pagination | Scroll to bottom | More devices load |
| Device status filter | Tap status chip | List filters |
| Device detail loads | Tap device | Detail view shows |
| Device action works | Tap action button | Status updates |
| Order list loads | Navigate to Orders tab | List displays |
| Order pagination | Scroll to bottom | More orders load |
| Order search | Enter search term | Results filter |
| Order detail loads | Tap order | Detail view shows |
| Order devices navigate | Tap device in order | Device detail opens |

## Acceptance Checklist

- [ ] Device list loads with pagination
- [ ] Device status filter works
- [ ] Device search works
- [ ] Device detail shows all info
- [ ] Device actions execute correctly
- [ ] All 18 device statuses display correctly
- [ ] Order list loads with pagination
- [ ] Order status filter works
- [ ] Order search works
- [ ] Order detail shows client, devices, totals
- [ ] Navigation between orders and devices works
- [ ] No decode errors in console

## Deployment

1. Build and run
2. Navigate to Devices tab, verify list loads
3. Test status filter
4. Tap device, verify detail loads
5. Test action buttons
6. Navigate to Orders tab, verify list loads
7. Tap order, verify detail with devices
8. Navigate from order device to device detail

## Handoff Notes

- DeviceStatusBadge from [See: Stage 04] is reused
- Device actions based on status from `device-workflows.js`
- Order detail includes nested devices array
- My Queue filter available via `filterToMyQueue` parameter
- [See: Stage 06] for ticket navigation from orders
