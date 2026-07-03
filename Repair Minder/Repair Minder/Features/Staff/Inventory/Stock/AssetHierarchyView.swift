import SwiftUI

/// Asset hierarchy: product-type groups (with child variants) + unlinked assets.
/// Asset rows navigate to the asset detail.
struct AssetHierarchyView: View {
    @ObservedObject var viewModel: StockViewModel
    let onSelectAsset: (String) -> Void

    @State private var expanded: Set<String> = []
    @State private var showUnlinked = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.hierarchy == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.hierarchy == nil {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Retry") { Task { await viewModel.load(.hierarchy) } }.buttonStyle(.borderedProminent)
                }.padding()
            } else if let hierarchy = viewModel.hierarchy {
                List {
                    Section {
                        ForEach(hierarchy.grouped) { group in
                            HierarchyGroupNode(group: group, depth: 0, expanded: $expanded, onSelectAsset: onSelectAsset)
                        }
                    } header: {
                        HStack {
                            Button("Expand all") { expandAll(hierarchy.grouped) }.font(.caption)
                            Spacer()
                            Button("Collapse all") { expanded.removeAll() }.font(.caption)
                        }
                    }
                    if !hierarchy.unlinked.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $showUnlinked) {
                                ForEach(hierarchy.unlinked) { HierarchyAssetRow(asset: $0, onSelectAsset: onSelectAsset) }
                            } label: {
                                Text("\(hierarchy.unlinked.count) unlinked asset\(hierarchy.unlinked.count == 1 ? "" : "s")").font(.subheadline.weight(.medium))
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.load(.hierarchy) }
            }
        }
    }

    private func expandAll(_ groups: [HierarchyGroup]) {
        for g in groups { expanded.insert(g.id); expandAll(g.children ?? []) }
    }
}

/// Recursive node — a `View` struct can reference itself (unlike a `@ViewBuilder` func).
private struct HierarchyGroupNode: View {
    let group: HierarchyGroup
    let depth: Int
    @Binding var expanded: Set<String>
    let onSelectAsset: (String) -> Void

    var body: some View {
        Button { toggle(group.id) } label: {
            HStack(spacing: 6) {
                Image(systemName: expanded.contains(group.id) ? "chevron.down" : "chevron.right").font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.productType.name).font(.subheadline.weight(.medium))
                    HStack(spacing: 6) {
                        if let count = group.children?.count, count > 0 { Text("\(count) variant\(count == 1 ? "" : "s")").font(.caption2).foregroundStyle(.secondary) }
                        Text("\(group.totalAssetCount) asset\(group.totalAssetCount == 1 ? "" : "s")").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.leading, CGFloat(depth) * 12)
        }
        .buttonStyle(.plain)

        if expanded.contains(group.id) {
            ForEach(group.assets) { asset in
                HierarchyAssetRow(asset: asset, onSelectAsset: onSelectAsset).padding(.leading, CGFloat(depth + 1) * 12)
            }
            ForEach(group.children ?? []) { child in
                HierarchyGroupNode(group: child, depth: depth + 1, expanded: $expanded, onSelectAsset: onSelectAsset)
            }
        }
    }

    private func toggle(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }
}

private struct HierarchyAssetRow: View {
    let asset: HierarchyAsset
    let onSelectAsset: (String) -> Void

    var body: some View {
        Button { onSelectAsset(asset.id) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.assetTag).font(.caption.monospaced())
                    Text(asset.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                AssetStatusBadge(status: asset.status)
            }
        }
        .buttonStyle(.plain)
    }
}
