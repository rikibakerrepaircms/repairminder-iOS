import SwiftUI

struct InventoryListView: View {
    var isEmbedded: Bool = false
    var onBack: (() -> Void)? = nil

    @StateObject private var viewModel = InventoryListViewModel()
    @State private var showFilters = false
    @State private var selectedAssetId: String?
    #if os(iOS)
    @State private var showScanner = false
    @State private var scanError: String?
    // InventoryService.init is @MainActor-isolated; hold one instance on the view
    // (created on the MainActor) rather than constructing per-lookup.
    private let service = InventoryService()
    #endif
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Group {
            if isEmbedded { embeddedBody }
            else if isRegularWidth { iPadBody }
            else { iPhoneBody }
        }
        .task { if viewModel.assets.isEmpty { await viewModel.loadAssets() } }
    }

    // Embedded (inside the More-tab NavigationStack — NO own stack)
    private var embeddedBody: some View {
        content
            .navigationTitle("Inventory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(item: $selectedAssetId) { InventoryDetailView(assetId: $0) }
            .toolbar { filterToolbar }
    }

    // Standalone iPhone tab (owns a stack)
    private var iPhoneBody: some View {
        NavigationStack {
            content
                .navigationTitle("Inventory")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .navigationDestination(item: $selectedAssetId) { InventoryDetailView(assetId: $0) }
                .toolbar { filterToolbar }
        }
    }

    // iPad split view (mirror Buyback)
    private var iPadBody: some View {
        AnimatedSplitView(showDetail: selectedAssetId != nil) {
            NavigationStack {
                content
                    .navigationTitle("Inventory")
                    .toolbar { filterToolbar }
            }
        } detail: {
            if let id = selectedAssetId {
                NavigationStack { InventoryDetailView(assetId: id) }.id(id)
            }
        }
    }

    // Shared content
    private var content: some View {
        VStack(spacing: 0) {
            statusPills
            mainList
        }
        .searchable(text: $viewModel.searchText, placement: searchPlacement, prompt: "Search tag, name, serial, SKU")
        .onChange(of: viewModel.searchText) { _, _ in viewModel.searchChanged() }
        .sheet(isPresented: $showFilters) {
            AssetFilterSheet(viewModel: viewModel)
        }
        #if os(iOS)
        .sheet(isPresented: $showScanner) {
            InventoryScannerSheet { tag in
                showScanner = false
                Task { await lookupTag(tag) }
            }
        }
        .alert("Not Found", isPresented: Binding(get: { scanError != nil }, set: { if !$0 { scanError = nil } }), presenting: scanError) { _ in
            Button("OK", role: .cancel) {}
        } message: { Text($0) }
        #endif
    }

    #if os(iOS)
    private var searchPlacement: SearchFieldPlacement { .navigationBarDrawer(displayMode: .always) }
    #else
    private var searchPlacement: SearchFieldPlacement { .automatic }
    #endif

    private var statusPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(title: "All", isOn: viewModel.selectedStatus == nil) { viewModel.selectStatus(nil) }
                ForEach(AssetStatus.allCases, id: \.self) { s in
                    pill(title: s.displayName, isOn: viewModel.selectedStatus == s) { viewModel.selectStatus(s) }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private func pill(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(isOn ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isOn ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundStyle(isOn ? Color.accentColor : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var mainList: some View {
        if viewModel.isLoading && viewModel.assets.isEmpty {
            Spacer(); ProgressView().frame(maxWidth: .infinity); Spacer()
        } else if let error = viewModel.error, viewModel.assets.isEmpty {
            errorView(error)
        } else if viewModel.assets.isEmpty {
            emptyView
        } else {
            List {
                ForEach(viewModel.assets) { asset in
                    Button { selectedAssetId = asset.id } label: { AssetRow(asset: asset) }
                        .buttonStyle(.plain)
                        .task { await viewModel.loadMoreIfNeeded(currentItem: asset) }
                }
                if viewModel.isLoadingMore {
                    HStack { Spacer(); ProgressView(); Spacer() }.listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.refresh() }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView("No Inventory", systemImage: "shippingbox",
            description: Text(viewModel.activeFilterCount > 0 || !viewModel.searchText.isEmpty ? "No matches for your filters." : "Inventory items will appear here."))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Retry") { Task { await viewModel.loadAssets() } }.buttonStyle(.borderedProminent)
        }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder private var filterToolbar: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
            Button { showScanner = true } label: { Image(systemName: "barcode.viewfinder") }
        }
        #endif
        ToolbarItem(placement: .primaryAction) {
            Button { showFilters = true } label: {
                Image(systemName: viewModel.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
        }
    }

    #if os(iOS)
    @MainActor
    private func lookupTag(_ tag: String) async {
        do {
            let asset = try await service.fetchAssetByTag(tag)
            selectedAssetId = asset.id
        } catch {
            scanError = "No asset found for tag \"\(tag)\"."
        }
    }
    #endif
}

private struct AssetRow: View {
    let asset: Asset
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(asset.assetTag).font(.subheadline.weight(.semibold).monospaced())
                Spacer()
                AssetStatusBadge(status: asset.status)
            }
            Text(asset.name).font(.body)
            HStack(spacing: 8) {
                if let cat = asset.category { Text(cat).font(.caption).foregroundStyle(.secondary) }
                if let loc = asset.locationDisplay { Label(loc, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary) }
            }
            if asset.status == .allocated || asset.status == .deployed,
               asset.checkedOutOrderNumber != nil || asset.checkedOutDeviceName != nil {
                HStack(spacing: 8) {
                    if let order = asset.checkedOutOrderNumber { Text("Order \(order)").font(.caption).foregroundStyle(.secondary) }
                    if let device = asset.checkedOutDeviceName { Text(device).font(.caption).foregroundStyle(.secondary) }
                }
            }
            if !asset.groupNamesList.isEmpty {
                HStack(spacing: 6) {
                    ForEach(asset.groupNamesList.prefix(2), id: \.self) { g in
                        Text(g).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill)).clipShape(Capsule())
                    }
                    if asset.groupNamesList.count > 2 { Text("+\(asset.groupNamesList.count - 2)").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            if let cost = asset.formattedCost {
                Text(cost).font(.subheadline.weight(.medium))
            }
        }
        .padding(.vertical, 4)
    }
}
