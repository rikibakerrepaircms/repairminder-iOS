import SwiftUI

struct KioskCatalogPanel: View {
    @ObservedObject var viewModel: KioskViewModel
    let onSelectProduct: (KioskProduct) -> Void

    @State private var viewMode: ViewMode = .grid
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil     // nil = All
    @State private var page = 1
    @State private var totalPages = 1
    @State private var total = 0
    @State private var products: [KioskProduct] = []
    @State private var categories: [KioskCategory] = []
    @State private var isLoading = false
    @State private var scanError: String?
    @State private var showScanner = false
    @State private var searchTask: Task<Void, Never>?

    enum ViewMode { case grid, list }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            categoryChips
            Divider()
            productArea
            paginationBar
        }
        .task { await initialLoad() }
        #if os(iOS)
        .sheet(isPresented: $showScanner) {
            InventoryScannerSheet { code in
                showScanner = false
                Task { await lookupSku(code) }
            }
        }
        #endif
        .alert("Product not found", isPresented: Binding(get: { scanError != nil }, set: { if !$0 { scanError = nil } })) {
            Button("OK") { scanError = nil }
        } message: { Text(scanError ?? "") }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search or scan barcode…", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, v in scheduleSearch(v) }
                if !searchText.isEmpty {
                    Button { searchText = "" ; scheduleSearch("") } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            #if os(iOS)
            Button { showScanner = true } label: { Image(systemName: "barcode.viewfinder") }
                .buttonStyle(.bordered)
            #endif

            Picker("", selection: $viewMode) {
                Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                Image(systemName: "list.bullet").tag(ViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 90)
            .labelsHidden()
        }
        .padding(10)
    }

    @ViewBuilder private var categoryChips: some View {
        if !categories.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "All", selected: selectedCategory == nil) {
                        if selectedCategory != nil { selectedCategory = nil; resetAndReload() }
                    }
                    ForEach(categories) { cat in
                        chip(title: cat.category, selected: selectedCategory == cat.category) {
                            selectedCategory = (selectedCategory == cat.category) ? nil : cat.category
                            resetAndReload()
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
            }
        }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var productArea: some View {
        if isLoading && products.isEmpty {
            ProgressView("Loading products…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if products.isEmpty {
            ContentUnavailableView(
                "No products found",
                systemImage: "shippingbox",
                description: Text(searchText.isEmpty && selectedCategory == nil
                    ? "No products in the catalog."
                    : "Try adjusting your search or filters."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                if viewMode == .grid {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(products) { p in
                            Button { onSelectProduct(p) } label: { KioskProductCardView(product: p) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(products) { p in
                            Button { onSelectProduct(p) } label: { KioskProductRowView(product: p) }
                                .buttonStyle(.plain)
                            Divider()
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    @ViewBuilder private var paginationBar: some View {
        if totalPages > 1 {
            HStack {
                Button { if page > 1 { page -= 1; reload() } } label: { Image(systemName: "chevron.left") }
                    .disabled(page <= 1)
                Spacer()
                Text("\(page) / \(totalPages) (\(total) items)").font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button { if page < totalPages { page += 1; reload() } } label: { Image(systemName: "chevron.right") }
                    .disabled(page >= totalPages)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(.bar)
        }
    }

    private func initialLoad() async {
        categories = (try? await viewModel.loadCategories()) ?? []
        await reloadAsync()
    }
    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            page = 1
            await reloadAsync()
        }
    }
    private func resetAndReload() { page = 1; reload() }
    private func reload() { Task { await reloadAsync() } }
    private func reloadAsync() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await viewModel.loadProducts(page: page, category: selectedCategory,
                                                        search: searchText.isEmpty ? nil : searchText)
            products = resp.data
            totalPages = max(1, resp.meta.totalPages)
            total = resp.meta.total
        } catch {
            products = []; totalPages = 1; total = 0
        }
    }
    private func lookupSku(_ sku: String) async {
        do {
            let product: KioskProduct = try await APIClient.shared.request(.productTypeBySku(sku: sku))
            onSelectProduct(product)
        } catch { scanError = "No product matches \(sku)." }
    }
}

// MARK: - Product card (grid)

struct KioskProductCardView: View {
    let product: KioskProduct
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .top) {
                KioskProductImage(productId: product.id, primaryImageId: product.primaryImageId, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                HStack {
                    if product.isTracked && !product.isOutOfStock {
                        badge("\(product.stockCount)", color: .green)
                    }
                    Spacer()
                    if product.isOutOfStock {
                        badge("Out of Stock", color: .red)
                    } else if product.isLowStock {
                        badge("Low Stock", color: .orange)
                    }
                }
                .padding(6)
            }
            Text(product.name).font(.subheadline.weight(.medium)).lineLimit(2)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            Text(product.priceIncVatText).font(.callout.weight(.bold)).foregroundStyle(.green)
        }
        .padding(10)
        .frame(minHeight: 150)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
        .contentShape(Rectangle())
    }
    private func badge(_ text: String, color: Color) -> some View {
        Text(text).font(.caption2.weight(.semibold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Product row (list)

struct KioskProductRowView: View {
    let product: KioskProduct
    var body: some View {
        HStack(spacing: 12) {
            KioskProductImage(productId: product.id, primaryImageId: product.primaryImageId, contentMode: .fill)
                .frame(width: 48, height: 48)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.subheadline.weight(.medium)).lineLimit(1)
                let subtitle = [product.sku, product.category].compactMap { $0 }.joined(separator: " · ")
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if product.isOutOfStock {
                Text("Out").font(.caption2).foregroundStyle(.red)
            } else if product.isLowStock {
                Text("Low").font(.caption2).foregroundStyle(.orange)
            } else if product.isTracked {
                Text("\(product.stockCount) in stock").font(.caption2).foregroundStyle(.secondary)
            }
            Text(product.priceIncVatText).font(.callout.weight(.bold)).foregroundStyle(.green)
                .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
