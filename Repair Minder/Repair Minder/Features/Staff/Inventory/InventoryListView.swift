import SwiftUI

enum InventoryMode: String, CaseIterable {
    case assets = "Assets", groups = "Groups", stock = "Stock"
}

/// Which bulk-action sheet is presented from the multi-select bottom bar.
enum BulkSheet: String, Identifiable {
    case move, deploy, returnSupplier, scan
    var id: String { rawValue }
}

struct InventoryListView: View {
    var isEmbedded: Bool = false
    var onBack: (() -> Void)? = nil

    @StateObject private var viewModel = InventoryListViewModel()
    @StateObject private var selection = BulkSelectionState()
    @State private var showFilters = false
    @State private var selectedAssetId: String?
    @State private var pendingDelete: Asset?
    @State private var mode: InventoryMode = .assets
    @State private var bulkSheet: BulkSheet?
    @State private var exportFile: ExportFile?
    @State private var showBookIn = false
    @State private var showImport = false
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
            modePicker
            switch mode {
            case .assets:
                if !selection.isEditing { LowStockBanner(onView: filterByProductType) }
                statusPills
                mainList
            case .groups:
                InventoryGroupsListView(externalSearch: viewModel.searchText)
            case .stock:
                InventoryStockView(onFilterByProductType: filterByProductType, onSelectAsset: { selectedAssetId = $0 })
            }
        }
        .searchable(text: $viewModel.searchText, placement: searchPlacement,
                    prompt: searchPrompt)
        .onChange(of: viewModel.searchText) { _, _ in if mode == .assets { viewModel.searchChanged() } }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryAssetDidChange)) { _ in
            Task { await viewModel.loadAssets() }
        }
        .confirmationDialog("Delete asset \(pendingDelete?.assetTag ?? "")?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let a = pendingDelete { Task { await deleteFromList(a) } }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
        .sheet(isPresented: $showFilters) {
            AssetFilterSheet(viewModel: viewModel)
        }
        .sheet(item: $bulkSheet) { bulkSheetView($0) }
        .sheet(isPresented: $showBookIn) { SupplierOrderListView() }
        .sheet(isPresented: $showImport) { AssetImportSheet() }
        #if os(iOS)
        .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
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
        .safeAreaInset(edge: .bottom) {
            if mode == .assets && selection.isEditing {
                let picked = selection.selectedAssets(from: viewModel.assets)
                if !picked.isEmpty {
                    BulkActionBar(
                        selectedAssets: picked,
                        onMove: { bulkSheet = .move },
                        onDeploy: { bulkSheet = .deploy },
                        onReturn: { bulkSheet = .returnSupplier },
                        onExport: exportSelectedCSV,
                        onScan: { bulkSheet = .scan })
                }
            }
        }
    }

    private var searchPrompt: String {
        switch mode {
        case .assets: return "Search tag, name, serial, SKU"
        case .groups: return "Search groups"
        case .stock: return "Stock analytics"
        }
    }

    /// Jump from an analytics view to the filtered Assets list.
    private func filterByProductType(_ productTypeId: String) {
        viewModel.selectedProductTypeId = productTypeId
        selection.exit()
        mode = .assets
        viewModel.applyFilters()
    }

    #if os(iOS)
    private var searchPlacement: SearchFieldPlacement { .navigationBarDrawer(displayMode: .always) }
    #else
    private var searchPlacement: SearchFieldPlacement { .automatic }
    #endif

    private var modePicker: some View {
        Picker("", selection: $mode) {
            ForEach(InventoryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12).padding(.top, 8)
        .accessibilityIdentifier("inventory-mode-picker")
    }

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
                    assetRow(asset)
                        .task { await viewModel.loadMoreIfNeeded(currentItem: asset) }
                        .swipeActions(edge: .trailing) {
                            if !selection.isEditing, asset.status != .allocated && asset.status != .deployed {
                                Button(role: .destructive) { pendingDelete = asset } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
                if viewModel.isLoadingMore {
                    HStack { Spacer(); ProgressView(); Spacer() }.listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.refresh() }
        }
    }

    @ViewBuilder private func assetRow(_ asset: Asset) -> some View {
        if selection.isEditing {
            Button {
                selection.toggle(asset.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selection.isSelected(asset.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection.isSelected(asset.id) ? Color.accentColor : .secondary)
                    AssetRow(asset: asset)
                }
            }
            .buttonStyle(.plain)
        } else {
            Button { selectedAssetId = asset.id } label: { AssetRow(asset: asset) }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder private func bulkSheetView(_ sheet: BulkSheet) -> some View {
        let picked = selection.selectedAssets(from: viewModel.assets)
        switch sheet {
        case .move:
            BulkMoveSheet(assets: picked) { selection.exit() }
        case .deploy:
            BulkDeploySheet(assets: picked) { selection.exit() }
        case .returnSupplier:
            BulkReturnToSupplierSheet(assets: picked) { selection.exit() }
        case .scan:
            #if os(iOS)
            BulkScanSheet { selection.exit() }
            #else
            EmptyView()
            #endif
        }
    }

    private func exportSelectedCSV() {
        let picked = selection.selectedAssets(from: viewModel.assets)
        guard !picked.isEmpty, let url = try? CSVExporter.writeTempFile(picked) else { return }
        exportFile = ExportFile(url: url)
    }

    private func deleteFromList(_ asset: Asset) async {
        defer { pendingDelete = nil }
        do {
            try await InventoryService().deleteAsset(id: asset.id)
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
        } catch {
            // List stays as-is; the detail screen surfaces mutation errors.
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
        if mode == .assets && selection.isEditing {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { selection.exit() }.accessibilityIdentifier("bulk-done")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Select All") { selection.selectAll(viewModel.assets.map(\.id)) }
                    Button("Clear Selection") { selection.clear() }
                } label: { Image(systemName: "checklist") }
            }
        } else {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Button { showScanner = true } label: { Image(systemName: "barcode.viewfinder") }
            }
            #endif
            if mode == .assets {
                ToolbarItem(placement: .automatic) {
                    Button("Select") { selection.isEditing = true }.accessibilityIdentifier("bulk-select")
                }
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button { showBookIn = true } label: { Label("Book In Stock", systemImage: "tray.and.arrow.down") }
                    Button { showImport = true } label: { Label("Import CSV", systemImage: "square.and.arrow.down.on.square") }
                } label: { Image(systemName: "tray.and.arrow.down") }
                .accessibilityIdentifier("inventory-tools-menu")
            }
            if mode == .assets {
                ToolbarItem(placement: .primaryAction) {
                    Button { showFilters = true } label: {
                        Image(systemName: viewModel.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
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

/// Identifiable wrapper so an exported CSV URL can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

#if os(iOS)
/// Minimal share-sheet wrapper for exporting a file via `UIActivityViewController`.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
