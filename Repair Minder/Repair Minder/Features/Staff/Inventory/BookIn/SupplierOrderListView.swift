import SwiftUI

/// Supplier-order (book-in) list. Presented as a sheet from the Inventory toolbar;
/// owns its own NavigationStack and pushes the book-in wizard.
struct SupplierOrderListView: View {
    @StateObject private var viewModel = SupplierOrderListViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var route: BookInRoute?
    @State private var showStatusFilter = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error, viewModel.orders.isEmpty {
                    VStack(spacing: 12) {
                        Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { Task { await viewModel.load() } }.buttonStyle(.borderedProminent)
                    }.padding()
                } else if viewModel.filtered.isEmpty {
                    ContentUnavailableView("No Orders", systemImage: "shippingbox",
                        description: Text("Tap + to create a supplier order and book in stock."))
                } else {
                    List {
                        ForEach(viewModel.filtered) { order in
                            Button { route = .edit(order.id) } label: { orderRow(order) }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    if order.status != "received" && order.status != "cancelled" {
                                        Button(role: .destructive) { Task { await viewModel.cancel(order) } } label: { Label("Cancel", systemImage: "xmark.circle") }
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Book In")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $viewModel.search, prompt: "Search supplier / reference")
            .onSubmit(of: .search) { Task { await viewModel.load() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { showStatusFilter = true } label: { Image(systemName: "line.3.horizontal.decrease.circle") } }
                ToolbarItem(placement: .primaryAction) {
                    Button { route = .new } label: { Image(systemName: "plus") }.accessibilityIdentifier("bookin-new")
                }
            }
            .navigationDestination(item: $route) { route in
                switch route {
                case .new: BookInWizardView(orderId: nil) { Task { await viewModel.load() } }
                case .edit(let id): BookInWizardView(orderId: id) { Task { await viewModel.load() } }
                }
            }
            .confirmationDialog("Show statuses", isPresented: $showStatusFilter, titleVisibility: .visible) {
                ForEach(SupplierOrderListViewModel.allStatuses, id: \.self) { status in
                    Button((viewModel.enabledStatuses.contains(status) ? "✓ " : "") + status.capitalized) { viewModel.toggleStatus(status) }
                }
            }
            .task { if viewModel.orders.isEmpty { await viewModel.load() } }
        }
    }

    private func orderRow(_ order: SupplierOrder) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(order.orderNumber ?? "Order").font(.subheadline.weight(.semibold))
                if let ref = order.supplierOrderReference { Text(ref).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Text(order.status.capitalized).font(.caption).padding(.horizontal, 8).padding(.vertical, 2)
                    .background(statusColor(order.status).opacity(0.15)).foregroundStyle(statusColor(order.status)).clipShape(Capsule())
            }
            Text(order.supplierName).font(.subheadline)
            HStack(spacing: 10) {
                Text("\(order.totalReceived ?? 0)/\(order.totalItems ?? 0) received").font(.caption).foregroundStyle(.secondary)
                if order.remainingCount > 0 && order.status == "partial" { Text("\(order.remainingCount) remaining").font(.caption).foregroundStyle(.orange) }
                Spacer()
                if let cost = order.totalCost { Text(CurrencyFormatter.format(cost)).font(.caption.weight(.medium)) }
            }
            if let date = order.orderDate { Text(date).font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "received": return .green
        case "partial": return .orange
        case "cancelled": return .red
        default: return .blue
        }
    }
}

enum BookInRoute: Hashable, Identifiable {
    case new
    case edit(String)   // order id
    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let orderId): return "edit-\(orderId)"
        }
    }
}
