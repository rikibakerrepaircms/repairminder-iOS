import SwiftUI

struct DeployToOrderWizard: View {
    let asset: Asset
    @ObservedObject var detailVM: InventoryDetailViewModel
    let onFinished: () -> Void

    @StateObject private var vm = DeployViewModel()
    @Environment(\.dismiss) private var dismiss

    private enum Step { case search, selectItem, confirm, done }
    @State private var step: Step = .search
    @State private var selectedOrder: Order?
    @State private var selectedItem: OrderItem?
    @State private var recovery: PartRecoveryState
    @State private var recoveredAsset: Asset?

    init(asset: Asset, detailVM: InventoryDetailViewModel, onFinished: @escaping () -> Void) {
        self.asset = asset
        self.detailVM = detailVM
        self.onFinished = onFinished
        _recovery = State(initialValue: PartRecoveryState(category: asset.category))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .search: searchStep
                case .selectItem: itemStep
                case .confirm: confirmStep
                case .done: doneStep
                }
            }
            .navigationTitle("Allocate to Order")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .done ? "Done" : "Cancel") {
                        if step == .done { onFinished() }
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchStep: some View {
        List {
            Section {
                TextField("Search orders…", text: $vm.orderQuery)
                    .onChange(of: vm.orderQuery) { _, _ in vm.searchChanged() }
            }
            if vm.isSearching { ProgressView() }
            ForEach(vm.orders) { order in
                Button {
                    selectedOrder = order
                    Task { await vm.loadItems(orderId: order.id); step = .selectItem }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Order #\(order.orderNumber)").font(.subheadline.weight(.semibold))
                        Text(order.status.label).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var itemStep: some View {
        List {
            if vm.isLoadingItems {
                ProgressView()
            } else if vm.items.isEmpty {
                Section {
                    Text("This order has no line items.").foregroundStyle(.secondary)
                    Button("Allocate without a line item") { selectedItem = nil; step = .confirm }
                }
            } else {
                Section("Select a line item (optional)") {
                    Button("No specific line item") { selectedItem = nil; step = .confirm }
                    ForEach(vm.items) { item in
                        Button {
                            selectedItem = item; step = .confirm
                        } label: { Text(item.description) }
                    }
                }
            }
        }
    }

    private var confirmStep: some View {
        Form {
            Section("Allocation") {
                LabeledContent("Asset", value: asset.assetTag)
                LabeledContent("Order", value: selectedOrder.map { "#\($0.orderNumber)" } ?? "—")
            }
            if asset.enablePartRecoveryBool { PartRecoveryForm(state: $recovery) }
            Section {
                Button("Allocate") { Task { await allocate() } }
                    .disabled(!recovery.isValid || detailVM.isMutating)
            }
            if let err = detailVM.actionError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.green)
            Text("Asset Allocated").font(.headline)
            if let r = recoveredAsset {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pulled Part Recovered").font(.subheadline.weight(.semibold))
                    Text(r.assetTag).font(.caption.monospaced())
                }
                .padding()
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.padding()
    }

    private func allocate() async {
        let body = AllocateRequest(orderId: selectedOrder?.id, deviceId: nil,
                                   orderItemId: selectedItem?.id, deploy: false,
                                   recovery: recovery.toInput())
        if let resp = await detailVM.allocate(body) {
            recoveredAsset = resp.recoveredAsset
            step = .done
        }
    }
}
