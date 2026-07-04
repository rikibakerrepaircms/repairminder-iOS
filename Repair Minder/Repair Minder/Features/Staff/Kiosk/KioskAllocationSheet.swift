import SwiftUI

struct KioskAllocationSheet: View {
    let productName: String
    let productTypeId: String
    let unitPrice: Double
    let vatRate: Double
    let initialQuantity: Int
    let initialAssetIds: Set<String>
    let onConfirm: ([KioskSelectedAsset], Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var assets: [KioskAvailableAsset] = []
    @State private var selected: Set<String> = []
    @State private var quantity: Int
    @State private var isLoading = true
    @State private var searchText = ""
    private let service: KioskServicing

    init(productName: String, productTypeId: String, unitPrice: Double, vatRate: Double,
         initialQuantity: Int, initialAssetIds: Set<String>,
         service: KioskServicing? = nil,
         onConfirm: @escaping ([KioskSelectedAsset], Int) -> Void) {
        self.productName = productName
        self.productTypeId = productTypeId
        self.unitPrice = unitPrice
        self.vatRate = vatRate
        self.initialQuantity = initialQuantity
        self.initialAssetIds = initialAssetIds
        self.service = service ?? KioskService()
        self.onConfirm = onConfirm
        _quantity = State(initialValue: max(1, initialQuantity))
        _selected = State(initialValue: initialAssetIds)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Stepper("Quantity: \(quantity)", value: $quantity, in: 1...max(1, assets.isEmpty ? 999 : assets.count))
                        }
                        Section("Available stock (\(assets.count))") {
                            ForEach(filtered) { asset in
                                assetRow(asset)
                            }
                        }
                    }
                    #if os(iOS)
                    .searchable(text: $searchText)
                    #endif
                }
            }
            .navigationTitle(productName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Skip") { onConfirm([], quantity); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { confirm(); dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private var filtered: [KioskAvailableAsset] {
        guard !searchText.isEmpty else { return assets }
        let q = searchText.lowercased()
        return assets.filter {
            $0.name.lowercased().contains(q)
            || ($0.assetTag?.lowercased().contains(q) ?? false)
            || ($0.serialNumber?.lowercased().contains(q) ?? false)
        }
    }

    private func assetRow(_ asset: KioskAvailableAsset) -> some View {
        Button {
            toggle(asset.id)
        } label: {
            HStack {
                Image(systemName: selected.contains(asset.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(asset.id) ? Color.accentColor : .secondary)
                VStack(alignment: .leading) {
                    Text(asset.name)
                    HStack(spacing: 8) {
                        if let tag = asset.assetTag { Text(tag) }
                        if let sn = asset.serialNumber { Text(sn) }
                        if let loc = asset.locationName { Text(loc) }
                    }.font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) }
        else if selected.count < quantity { selected.insert(id) }
    }

    private func confirm() {
        let chosen = assets.filter { selected.contains($0.id) }.map {
            KioskSelectedAsset(id: $0.id, name: $0.name, assetTag: $0.assetTag, cost: $0.cost,
                serialNumber: $0.serialNumber, locationName: $0.locationName, subLocation: $0.subLocation)
        }
        onConfirm(chosen, quantity)
    }

    private func load() async {
        isLoading = true; defer { isLoading = false }
        do { assets = try await service.availableAssets(productTypeId: productTypeId, search: nil) }
        catch { assets = [] }
    }
}
