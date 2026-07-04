import SwiftUI

struct KioskCatalogPanel: View {
    @ObservedObject var viewModel: KioskViewModel
    let onSelectProduct: (ProductTypeSearchResult) -> Void
    let onAddCustomItem: () -> Void

    @State private var query: String = ""
    @State private var results: [ProductTypeSearchResult] = []
    @State private var isLoading = false
    @State private var showScanner = false
    @State private var scanError: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search products", text: $query)
                    .textFieldStyle(.plain)
                    .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
                if !query.isEmpty {
                    Button { query = ""; results = [] } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            HStack {
                #if os(iOS)
                Button { showScanner = true } label: {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }.buttonStyle(.bordered)
                #endif
                Spacer()
                Button { onAddCustomItem() } label: {
                    Label("Custom Item", systemImage: "plus.circle")
                }.buttonStyle(.bordered)
            }
        }
        .padding()
        #if os(iOS)
        .sheet(isPresented: $showScanner) {
            InventoryScannerSheet { code in
                showScanner = false
                Task { await lookupSku(code) }
            }
        }
        #endif
        .alert("Product not found", isPresented: .constant(scanError != nil)) {
            Button("OK") { scanError = nil }
        } message: { Text(scanError ?? "") }
    }

    @ViewBuilder private var content: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty {
            ContentUnavailableView("Search the catalog",
                systemImage: "shippingbox",
                description: Text("Find a product, scan a barcode, or add a custom item."))
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(results) { product in
                        Button { onSelectProduct(product) } label: { productCard(product) }
                            .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    private func productCard(_ p: ProductTypeSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.name).font(.subheadline.weight(.semibold)).lineLimit(2)
            if let sku = p.sku { Text(sku).font(.caption).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
            Text(p.formattedPrice ?? "£0.00").font(.callout.weight(.bold))
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await runSearch(trimmed)
        }
    }

    private func runSearch(_ text: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let r: [ProductTypeSearchResult] = try await APIClient.shared.request(.productTypes(search: text))
            if !Task.isCancelled { results = r }
        } catch { results = [] }
    }

    private func lookupSku(_ sku: String) async {
        do {
            let product: ProductTypeSearchResult = try await APIClient.shared.request(.productTypeBySku(sku: sku))
            onSelectProduct(product)
        } catch {
            scanError = "No product matches \(sku)."
        }
    }
}
