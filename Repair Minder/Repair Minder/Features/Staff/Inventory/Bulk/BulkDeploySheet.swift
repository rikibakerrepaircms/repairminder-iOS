import SwiftUI

/// Bulk deploy of the in-stock selection: allocate to an order (optional line item)
/// or deploy externally. Each asset is a separate call; partial failure tolerated.
struct BulkDeploySheet: View {
    @StateObject private var viewModel: BulkDeployViewModel
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    private enum Step { case choice, order, external, progress }
    @State private var step: Step = .choice

    // Order path
    @State private var orderSearch = ""
    @State private var orders: [Order] = []
    @State private var selectedOrder: Order?
    @State private var lineItems: [OrderItem] = []
    @State private var selectedItemId: String?
    @State private var isSearching = false

    // External path
    @State private var customerName = ""
    @State private var externalReference = ""
    @State private var externalNotes = ""
    @State private var deploymentDate = Date()

    init(assets: [Asset], onDone: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: BulkDeployViewModel(assets: assets))
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .choice: choiceView
                case .order: orderView
                case .external: externalView
                case .progress: progressView
                }
            }
            .navigationTitle("Deploy \(viewModel.assets.count)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.finished ? "Done" : "Cancel") { if viewModel.finished { onDone() }; dismiss() }
                }
            }
        }
    }

    private var choiceView: some View {
        List {
            if viewModel.assets.isEmpty {
                Text("None of the selected assets are in stock.").foregroundStyle(.secondary)
            } else {
                Button { step = .order } label: { Label("Allocate to Order", systemImage: "shippingbox") }
                Button { step = .external } label: { Label("Deploy Externally", systemImage: "person.crop.circle.badge.checkmark") }
            }
        }
    }

    private var orderView: some View {
        List {
            Section {
                TextField("Search orders", text: $orderSearch)
                    .onSubmit { Task { await searchOrders() } }
                if isSearching { ProgressView() }
            }
            if let order = selectedOrder {
                Section("Selected order") {
                    Text("Order \(order.orderNumber) · \(order.clientDisplayName)")
                    if lineItems.isEmpty {
                        Text("This order has no line items. Add one first.").foregroundStyle(.secondary)
                    } else {
                        Picker("Line item", selection: $selectedItemId) {
                            Text("Select…").tag(String?.none)
                            ForEach(lineItems) { Text($0.description).tag(String?.some($0.id)) }
                        }
                    }
                }
                Section {
                    Button("Allocate \(viewModel.assets.count)") {
                        step = .progress
                        Task { await viewModel.runOrder(orderId: order.id, orderItemId: selectedItemId) }
                    }
                    .disabled(!AssetActions.canConfirmDeployToOrder(hasLineItem: selectedItemId != nil))
                }
            } else {
                ForEach(orders) { order in
                    Button {
                        selectedOrder = order
                        Task { lineItems = (try? await InventoryService().fetchOrderItems(orderId: order.id)) ?? [] }
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Order \(order.orderNumber)").font(.subheadline.weight(.medium))
                            Text("\(order.clientDisplayName) · \(order.status.label)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var externalView: some View {
        Form {
            Section("Customer") {
                TextField("Customer name", text: $customerName)
                TextField("Reference / job number", text: $externalReference)
            }
            Section("Deployment") {
                DatePicker("Date", selection: $deploymentDate, displayedComponents: .date)
                TextField("Notes", text: $externalNotes, axis: .vertical).lineLimit(2...4)
            }
            Section {
                Button("Deploy \(viewModel.assets.count)") {
                    step = .progress
                    Task {
                        await viewModel.runExternal(BulkDeploySheet.buildExternalRequest(
                            customerName: customerName,
                            externalReference: externalReference,
                            notes: externalNotes,
                            deploymentDate: deploymentDate))
                    }
                }
            }
        }
    }

    /// Pure builder (testable) — mirrors the single-asset `DeployExternalSheet` encoding exactly.
    static func buildExternalRequest(customerName: String, externalReference: String, notes: String, deploymentDate: Date) -> DeployExternalRequest {
        DeployExternalRequest(
            customerName: customerName.isEmpty ? nil : customerName,
            externalReference: externalReference.isEmpty ? nil : externalReference,
            notes: notes.isEmpty ? nil : notes,
            deploymentDate: DeployExternalRequest.isoDateString(from: deploymentDate))
    }

    private var progressView: some View {
        Form {
            Section { BulkProgressView(total: viewModel.assets.count, outcomes: viewModel.outcomes, isRunning: viewModel.isRunning) }
        }
    }

    private func searchOrders() async {
        isSearching = true; defer { isSearching = false }
        orders = (try? await InventoryService().searchOrders(search: orderSearch)) ?? []
    }
}
