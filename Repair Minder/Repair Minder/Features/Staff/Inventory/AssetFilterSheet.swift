import SwiftUI

/// Loads the picker option lists for the filter sheet.
@MainActor
final class AssetFilterOptions: ObservableObject {
    @Published var categories: [String] = []
    @Published var locations: [Location] = []
    @Published var subLocations: [AssetSubLocationOption] = []
    @Published var groups: [AssetGroupListItem] = []
    @Published var productTypes: [ProductTypeOption] = []

    private let service: InventoryServing
    // NB: InventoryService.init is @MainActor-isolated, so it cannot be a default
    // arg value in a nonisolated context. Use optional + nil-coalesce instead.
    init(service: InventoryServing? = nil) { self.service = service ?? InventoryService() }

    func loadTopLevel() async {
        async let cats = try? service.fetchCategories()
        async let locs = try? service.fetchLocations()
        async let grps = try? service.fetchGroups(search: nil)
        categories = await cats ?? []
        locations = await locs ?? []
        groups = await grps ?? []
    }

    func loadSubLocations(locationId: String) async {
        subLocations = (try? await service.fetchSubLocations(locationId: locationId)) ?? []
    }

    func searchProductTypes(_ query: String) async {
        guard !query.isEmpty else { productTypes = []; return }
        productTypes = (try? await service.fetchProductTypes(search: query)) ?? []
    }

    /// Hybrid group lookup (NTH-3): the default list loads on appear so small companies
    /// see their groups immediately; typing refines server-side to reach groups beyond
    /// the first-page/100 cap; clearing the field restores the default list.
    func searchGroups(_ query: String) async {
        groups = (try? await service.fetchGroups(search: query.isEmpty ? nil : query)) ?? []
    }
}

struct AssetFilterSheet: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @StateObject private var options = AssetFilterOptions()
    @Environment(\.dismiss) private var dismiss
    @State private var productTypeQuery = ""
    @State private var groupQuery = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        Text("Any").tag(String?.none)
                        ForEach(options.categories, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                }
                Section("Location") {
                    Picker("Location", selection: $viewModel.selectedLocationId) {
                        Text("Any").tag(String?.none)
                        ForEach(options.locations) { Text($0.name).tag(String?.some($0.id)) }
                    }
                    .onChange(of: viewModel.selectedLocationId) { _, new in
                        viewModel.selectedSubLocationId = nil
                        if let id = new { Task { await options.loadSubLocations(locationId: id) } }
                        else { options.subLocations = [] }
                    }
                    if !options.subLocations.isEmpty {
                        Picker("Sub-location", selection: $viewModel.selectedSubLocationId) {
                            Text("Any").tag(String?.none)
                            ForEach(options.subLocations) { Text($0.code ?? $0.description ?? "—").tag(String?.some($0.id)) }
                        }
                    }
                }
                Section("Group") {
                    TextField("Search groups…", text: $groupQuery)
                        .onChange(of: groupQuery) { _, q in Task { await options.searchGroups(q) } }
                    ForEach(options.groups) { g in
                        Button {
                            viewModel.selectedGroupId = g.id
                            groupQuery = g.name
                        } label: {
                            HStack {
                                Text(g.name)
                                Spacer()
                                if viewModel.selectedGroupId == g.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    if viewModel.selectedGroupId != nil {
                        Button("Clear group", role: .destructive) {
                            viewModel.selectedGroupId = nil; groupQuery = ""
                        }
                    }
                }
                Section("Product Type") {
                    TextField("Search product types…", text: $productTypeQuery)
                        .onChange(of: productTypeQuery) { _, q in Task { await options.searchProductTypes(q) } }
                    ForEach(options.productTypes) { pt in
                        Button {
                            viewModel.selectedProductTypeId = pt.id
                            productTypeQuery = pt.name
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(pt.name)
                                    if let sku = pt.sku, !sku.isEmpty {
                                        Text(sku).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if viewModel.selectedProductTypeId == pt.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    if viewModel.selectedProductTypeId != nil {
                        Button("Clear product type", role: .destructive) {
                            viewModel.selectedProductTypeId = nil; productTypeQuery = ""
                        }
                    }
                }
                Section {
                    Toggle("Unassigned (no groups)", isOn: $viewModel.unassignedOnly)
                    Toggle("No products", isOn: $viewModel.noProductsOnly)
                }
            }
            .navigationTitle("Filters")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { viewModel.clearFilters(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { viewModel.applyFilters(); dismiss() }
                }
            }
            .task { await options.loadTopLevel() }
        }
    }
}
