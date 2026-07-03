import SwiftUI

struct InventoryGroupDetailView: View {
    let groupId: String
    @StateObject private var vm: InventoryGroupDetailViewModel
    @State private var showEdit = false
    @State private var showPromote = false
    @State private var showAddAssets = false

    init(groupId: String) {
        self.groupId = groupId
        _vm = StateObject(wrappedValue: InventoryGroupDetailViewModel(groupId: groupId))
    }

    var body: some View {
        List {
            if let g = vm.group {
                Section {
                    if let sku = g.sku, !sku.isEmpty { Text(sku).font(.caption.monospaced()).foregroundStyle(.secondary) }
                    HStack {
                        Label("\(g.inStockCount ?? 0) in stock", systemImage: "shippingbox")
                        Spacer()
                        Text("\(g.totalAssetCount ?? 0) total").foregroundStyle(.secondary)
                    }.font(.subheadline)
                    if GroupActions.alreadyLinked(g) {
                        Text("Linked to \(g.linkedProductCount ?? 0) product(s). Creating another shares the same stock.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            Picker("", selection: $vm.tab) {
                Text("Member Assets").tag(InventoryGroupDetailViewModel.Tab.assets)
                Text("Linked Products").tag(InventoryGroupDetailViewModel.Tab.products)
            }.pickerStyle(.segmented)

            if let e = vm.errorMessage { Text(e).foregroundStyle(.red) }

            if vm.tab == .assets { assetsSection } else { productsSection }
        }
        .navigationTitle(vm.group?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showEdit = true } label: { Image(systemName: "pencil") }
                    .accessibilityIdentifier("group-edit")
                Button { showPromote = true } label: { Image(systemName: "arrow.up.right") }
                    .accessibilityIdentifier("group-promote")
            }
        }
        .sheet(isPresented: $showEdit) { if let g = vm.group { GroupEditSheet(group: g) { Task { await vm.load() } } } }
        .sheet(isPresented: $showPromote) { if let g = vm.group { PromoteToProductSheet(group: g) { Task { await vm.load() } } } }
        .sheet(isPresented: $showAddAssets) { GroupAddAssetsSheet(vm: vm) }
        .task { await vm.load() }
    }

    private var assetsSection: some View {
        Section {
            Button { showAddAssets = true } label: { Label("Add Assets", systemImage: "plus") }
                .accessibilityIdentifier("group-add-assets")
            ForEach(vm.assets) { asset in
                GroupMemberAssetRow(asset: asset)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { Task { await vm.removeMember(assetId: asset.id) } } label: { Label("Remove", systemImage: "trash") }
                    }
                    .onAppear { if asset.id == vm.assets.last?.id { Task { await vm.loadMoreAssets() } } }
            }
            if vm.assets.isEmpty && !vm.isLoading { Text("No assets in this group").foregroundStyle(.secondary) }
        }
    }

    private var productsSection: some View {
        Section {
            ForEach(vm.products) { product in
                LinkedProductRow(product: product)
            }
            if vm.products.isEmpty && !vm.isLoading { Text("No products linked").foregroundStyle(.secondary) }
        }
    }
}

private struct GroupMemberAssetRow: View {
    let asset: Asset
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(asset.assetTag).font(.subheadline.monospaced())
            Text(asset.name).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct LinkedProductRow: View {
    let product: LinkedProduct
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(product.name).font(.subheadline)
            HStack(spacing: 8) {
                if let sku = product.sku { Text(sku).font(.caption.monospaced()).foregroundStyle(.secondary) }
                if let t = product.qualityTier { Text(t).font(.caption).foregroundStyle(Color.accentColor) }
                if let q = product.quantityRequired { Text("Qty \(q)").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

/// Search in-stock assets and add them to the group.
struct GroupAddAssetsSheet: View {
    @ObservedObject var vm: InventoryGroupDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var results: [Asset] = []
    @State private var isSearching = false
    @State private var searchFailed = false
    private let service = InventoryService()

    var body: some View {
        NavigationStack {
            List {
                if let e = vm.errorMessage { Text(e).foregroundStyle(.red) }
                ForEach(results) { asset in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(asset.name)
                            Text(asset.assetTag).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Add") {
                            Task {
                                if await vm.addMember(assetId: asset.id) {
                                    results.removeAll { $0.id == asset.id }
                                }
                            }
                        }.disabled(vm.isMutating)
                    }
                }
                if isSearching { ProgressView() }
                else if searchFailed { Text("Couldn't search assets. Try again.").foregroundStyle(.red) }
                else if !search.isEmpty && results.isEmpty { Text("No matching in-stock assets").foregroundStyle(.secondary) }
            }
            .searchable(text: $search)
            .task(id: search) { await runSearch() }
            .navigationTitle("Add Assets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func runSearch() async {
        searchFailed = false
        let term = search.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { results = []; return }
        isSearching = true; defer { isSearching = false }
        do {
            // Construct AssetQuery for an in-stock text search — all other filters default to nil.
            let query = AssetQuery(status: "in_stock", search: term)
            let found = try await service.fetchAssets(page: 1, pageSize: 10, filters: query)
            let existing = Set(vm.assets.map(\.id))
            results = found.filter { !existing.contains($0.id) }
            searchFailed = false
        } catch { results = []; searchFailed = true }
    }
}
