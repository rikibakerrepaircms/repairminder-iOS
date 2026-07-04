import SwiftUI

/// Embedded (the parent supplies the NavigationStack) — mirrors how the assets
/// list content is hosted inside InventoryListView's shared stack.
struct InventoryGroupsListView: View {
    @StateObject private var vm = InventoryGroupsListViewModel()
    var externalSearch: String
    @State private var route: GroupRoute?
    @State private var promotingGroup: InventoryGroup?

    /// Distinct Identifiable wrapper to avoid colliding with the asset-detail
    /// navigationDestination(item:) keyed on String in the same NavigationStack.
    struct GroupRoute: Identifiable, Hashable { let id: String }

    var body: some View {
        List {
            Section {
                Picker("Category", selection: Binding(
                    get: { vm.category ?? "" },
                    set: { vm.category = $0.isEmpty ? nil : $0 }
                )) {
                    Text("All categories").tag("")
                    ForEach(vm.knownCategories, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Has products", isOn: $vm.hasProducts)
                Toggle("Empty groups", isOn: $vm.emptyGroups)
                Picker("Sort by", selection: $vm.sortField) {
                    ForEach(InventoryGroupsListViewModel.SortField.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Ascending", isOn: $vm.sortAscending)
            }
            if let e = vm.errorMessage { Text(e).foregroundStyle(.red) }
            if let total = vm.total {
                Text("\(total) group\(total == 1 ? "" : "s") found")
                    .font(.caption).foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
            if vm.groups.isEmpty && !vm.isLoading {
                ContentUnavailableView("No inventory groups", systemImage: "shippingbox")
            }
            ForEach(vm.groups) { group in
                Button { route = GroupRoute(id: group.id) } label: { GroupRow(group: group) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("group-row-\(group.sku ?? group.id)")
                    .swipeActions(edge: .trailing) {
                        Button { promotingGroup = group } label: { Label("Promote", systemImage: "arrow.up.right") }
                            .tint(.accentColor)
                    }
                    .onAppear { if group.id == vm.groups.last?.id { Task { await vm.loadMore() } } }
            }
            if vm.isLoadingMore {
                HStack { Spacer(); ProgressView(); Spacer() }.listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .overlay { if vm.isLoading && vm.groups.isEmpty { ProgressView() } }
        .navigationDestination(item: $route) { r in InventoryGroupDetailView(groupId: r.id) }
        .sheet(item: $promotingGroup) { g in PromoteToProductSheet(group: g) { Task { await vm.load() } } }
        .task(id: externalSearch) { vm.search = externalSearch; await vm.load() }
        .onChange(of: vm.category) { _, _ in Task { await vm.load() } }
        .onChange(of: vm.hasProducts) { _, _ in Task { await vm.load() } }
        .onChange(of: vm.emptyGroups) { _, _ in Task { await vm.load() } }
        .onChange(of: vm.sortField) { _, _ in Task { await vm.load() } }
        .onChange(of: vm.sortAscending) { _, _ in Task { await vm.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryAssetDidChange)) { _ in Task { await vm.load() } }
    }
}

private struct GroupRow: View {
    let group: InventoryGroup
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(group.name).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(group.inStockCount ?? 0)").font(.subheadline.weight(.semibold)).foregroundStyle(GroupActions.stockColor(group))
            }
            HStack(spacing: 8) {
                if let sku = group.sku, !sku.isEmpty { Text(sku).font(.caption.monospaced()).foregroundStyle(.secondary) }
                if let cat = group.category, !cat.isEmpty { Text(cat).font(.caption).foregroundStyle(.secondary) }
            }
            HStack(spacing: 12) {
                Text("Total \(group.totalAssetCount ?? 0)").font(.caption2).foregroundStyle(.secondary)
                if let lp = group.linkedProductCount, lp > 0 { Text("\(lp) product\(lp == 1 ? "" : "s")").font(.caption2).foregroundStyle(Color.accentColor) }
                if let r = group.reorderLevel, r > 0 { Text("Reorder \(r)").font(.caption2).foregroundStyle(.secondary) }
            }
        }
        .padding(.vertical, 4)
    }
}
