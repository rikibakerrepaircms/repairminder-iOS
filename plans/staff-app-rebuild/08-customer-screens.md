# Stage 08: Customer Screens

## Objective

Build customer-facing screens within the **unified app target**. Customer views live in `Features/Customer/` alongside Staff features, sharing models, networking, and components.

## Dependencies

- **Requires**: Stage 02 (CustomerModels), Stage 03 (CustomerAuthManager, AppState with role support)
- **Shares**: APIClient, KeychainManager, shared components

## Complexity

**Medium** - New views following established patterns from Staff features

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Customer/Orders/CustomerOrderListView.swift` | List of customer's orders |
| `Features/Customer/Orders/CustomerOrderListViewModel.swift` | Order list logic |
| `Features/Customer/Orders/CustomerOrderDetailView.swift` | Order detail with quote approval |
| `Features/Customer/Orders/CustomerOrderDetailViewModel.swift` | Order detail logic |
| `Features/Customer/Orders/Components/CustomerOrderRow.swift` | Order list row |
| `Features/Customer/Orders/Components/QuoteApprovalSheet.swift` | Signature capture for approval |
| `Features/Customer/Profile/CustomerProfileView.swift` | Customer profile/settings |
| `Features/Customer/CustomerMainTabView.swift` | Tab container for customer |

---

## Implementation Details

### CustomerOrderListView.swift

```swift
// Features/Customer/Orders/CustomerOrderListView.swift

import SwiftUI

struct CustomerOrderListView: View {
    @State private var viewModel = CustomerOrderListViewModel()

    var body: some View {
        List {
            // Action Required Section
            if !viewModel.actionRequiredOrders.isEmpty {
                Section("Action Required") {
                    ForEach(viewModel.actionRequiredOrders) { order in
                        NavigationLink(value: order) {
                            CustomerOrderRow(order: order)
                        }
                    }
                }
            }

            // Active Orders Section
            if !viewModel.activeOrders.isEmpty {
                Section("In Progress") {
                    ForEach(viewModel.activeOrders) { order in
                        NavigationLink(value: order) {
                            CustomerOrderRow(order: order)
                        }
                    }
                }
            }

            // Completed Section
            if !viewModel.completedOrders.isEmpty {
                Section("Completed") {
                    ForEach(viewModel.completedOrders) { order in
                        NavigationLink(value: order) {
                            CustomerOrderRow(order: order)
                        }
                    }
                }
            }
        }
        .navigationTitle("My Orders")
        .navigationDestination(for: CustomerOrder.self) { order in
            CustomerOrderDetailView(orderId: order.id)
        }
        .refreshable {
            await viewModel.loadOrders()
        }
        .task {
            await viewModel.loadOrders()
        }
        .overlay {
            if viewModel.isLoading && viewModel.orders.isEmpty {
                ProgressView()
            } else if viewModel.orders.isEmpty {
                ContentUnavailableView(
                    "No Orders",
                    systemImage: "doc.text",
                    description: Text("You don't have any orders yet")
                )
            }
        }
    }
}
```

### CustomerOrderListViewModel.swift

```swift
// Features/Customer/Orders/CustomerOrderListViewModel.swift

import Foundation

@MainActor
@Observable
final class CustomerOrderListViewModel {
    private(set) var orders: [CustomerOrder] = []
    private(set) var isLoading = false
    private(set) var error: String?

    // Filtered sections
    var actionRequiredOrders: [CustomerOrder] {
        orders.filter { order in
            order.devices.contains { device in
                device.status == .awaitingAuthorisation
            }
        }
    }

    var activeOrders: [CustomerOrder] {
        orders.filter { order in
            !actionRequiredOrders.contains { $0.id == order.id } &&
            order.status != "completed" && order.status != "collected"
        }
    }

    var completedOrders: [CustomerOrder] {
        orders.filter { order in
            order.status == "completed" || order.status == "collected"
        }
    }

    func loadOrders() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            orders = try await APIClient.shared.request(
                .customerOrders(),
                responseType: [CustomerOrder].self
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### CustomerOrderDetailView.swift

```swift
// Features/Customer/Orders/CustomerOrderDetailView.swift

import SwiftUI

struct CustomerOrderDetailView: View {
    let orderId: String
    @State private var viewModel: CustomerOrderDetailViewModel
    @State private var showApprovalSheet = false

    init(orderId: String) {
        self.orderId = orderId
        self._viewModel = State(initialValue: CustomerOrderDetailViewModel(orderId: orderId))
    }

    var body: some View {
        ScrollView {
            if let order = viewModel.order {
                VStack(spacing: 16) {
                    // Order Header
                    OrderHeaderCard(order: order)

                    // Devices
                    ForEach(order.devices) { device in
                        CustomerDeviceCard(
                            device: device,
                            onApprove: {
                                showApprovalSheet = true
                            }
                        )
                    }

                    // Quote Items
                    if !order.items.isEmpty {
                        QuoteItemsCard(items: order.items, totals: order.totals)
                    }

                    // Messages
                    if !order.messages.isEmpty {
                        MessagesCard(messages: order.messages)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.order?.displayRef ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadOrder()
        }
        .task {
            await viewModel.loadOrder()
        }
        .overlay {
            if viewModel.isLoading && viewModel.order == nil {
                ProgressView()
            }
        }
        .sheet(isPresented: $showApprovalSheet) {
            if let order = viewModel.order {
                QuoteApprovalSheet(
                    order: order,
                    onApprove: { signatureType, signatureData in
                        await viewModel.approveQuote(
                            signatureType: signatureType,
                            signatureData: signatureData
                        )
                    },
                    onReject: { reason in
                        await viewModel.rejectQuote(reason: reason)
                    }
                )
            }
        }
    }
}
```

### CustomerOrderDetailViewModel.swift

```swift
// Features/Customer/Orders/CustomerOrderDetailViewModel.swift

import Foundation

@MainActor
@Observable
final class CustomerOrderDetailViewModel {
    let orderId: String
    private(set) var order: CustomerOrderDetail?
    private(set) var isLoading = false
    private(set) var error: String?

    init(orderId: String) {
        self.orderId = orderId
    }

    func loadOrder() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            order = try await APIClient.shared.request(
                .customerOrder(id: orderId),
                responseType: CustomerOrderDetail.self
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func approveQuote(signatureType: String, signatureData: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let request = QuoteApprovalRequest(
                action: "approve",
                signatureType: signatureType,
                signatureData: signatureData,
                amountAcknowledged: order?.totals.grandTotal,
                rejectionReason: nil
            )

            _ = try await APIClient.shared.request(
                .customerApproveOrder(orderId: orderId, request: request),
                responseType: QuoteApprovalResponse.self
            )

            // Reload order to get updated status
            await loadOrder()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func rejectQuote(reason: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let request = QuoteApprovalRequest(
                action: "reject",
                signatureType: "typed",
                signatureData: CustomerAuthManager.shared.currentClient?.displayName ?? "",
                amountAcknowledged: nil,
                rejectionReason: reason
            )

            _ = try await APIClient.shared.request(
                .customerApproveOrder(orderId: orderId, request: request),
                responseType: QuoteApprovalResponse.self
            )

            await loadOrder()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendReply(message: String, deviceId: String? = nil) async {
        do {
            _ = try await APIClient.shared.request(
                .customerReply(orderId: orderId, message: message, deviceId: deviceId),
                responseType: CustomerReplyResponse.self
            )

            await loadOrder()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### CustomerProfileView.swift

```swift
// Features/Customer/Profile/CustomerProfileView.swift

import SwiftUI

struct CustomerProfileView: View {
    @Environment(AppState.self) private var appState

    var client: CustomerClient? {
        CustomerAuthManager.shared.currentClient
    }

    var company: CustomerCompany? {
        CustomerAuthManager.shared.currentCompany
    }

    var body: some View {
        List {
            // Profile Section
            Section {
                if let client = client {
                    LabeledContent("Name", value: client.displayName)
                    LabeledContent("Email", value: client.email)
                }

                if let company = company {
                    LabeledContent("Repair Shop", value: company.name)
                }
            }

            // Sign Out
            Section {
                Button(role: .destructive) {
                    Task {
                        await CustomerAuthManager.shared.logout()
                    }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Profile")
    }
}
```

### Update Repair_MinderApp.swift

The customer tab view is already defined in Stage 03. Ensure it uses these views:

```swift
// In CustomerMainTabView (from Stage 03)

@ViewBuilder
private func customerView(for tab: AppState.CustomerTab) -> some View {
    switch tab {
    case .orders:
        CustomerOrderListView()
    case .settings:
        CustomerProfileView()
    }
}
```

---

## Test Cases

| Test | Steps | Expected |
|------|-------|----------|
| Customer login | Enter email, receive code, verify | Customer tabs visible |
| Orders list | Login as customer | Orders grouped by status |
| Order detail | Tap order row | Full detail with devices, items, totals |
| Quote approval | Tap approve, sign, submit | Status updates to authorised |
| Quote rejection | Tap reject, enter reason | Status updates to rejected |
| Send message | Type message, tap send | Message appears in list |
| Logout | Tap sign out | Returns to customer login |

## Acceptance Checklist

### Views
- [ ] CustomerOrderListView shows orders in sections (Action Required, In Progress, Completed)
- [ ] CustomerOrderDetailView shows full order information
- [ ] QuoteApprovalSheet captures signature (typed or drawn)
- [ ] CustomerProfileView shows client info and logout button

### API Integration
- [ ] CustomerOrderListViewModel calls `GET /api/customer/orders`
- [ ] CustomerOrderDetailViewModel calls `GET /api/customer/orders/:id`
- [ ] Quote approval calls `POST /api/customer/orders/:id/approve`
- [ ] Quote rejection sends rejection reason
- [ ] Reply calls `POST /api/customer/orders/:id/reply`

### Navigation
- [ ] Tab bar shows Orders and Profile tabs
- [ ] Order list navigates to detail view
- [ ] Logout returns to customer login screen

## Handoff Notes

- Customer views follow same patterns as Staff features
- All views in `Features/Customer/` within main target
- Uses shared `CustomerAuthManager` from Stage 03
- Uses `CustomerModels` from Stage 02
- Uses same `APIClient` as Staff features
- [See: Stage 02] for CustomerModels
- [See: Stage 03] for CustomerAuthManager and app entry point
