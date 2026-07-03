import SwiftUI

struct AssetEditSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var serialNumber: String
    @State private var sku: String
    @State private var category: String
    @State private var conditionGrade: String
    @State private var isOem: Bool
    @State private var isRefurbished: Bool
    @State private var warrantyMonths: String
    @State private var notes: String
    @State private var categorySuggestions: [String] = []

    init(asset: Asset, viewModel: InventoryDetailViewModel) {
        self.asset = asset
        self.viewModel = viewModel
        _serialNumber = State(initialValue: asset.serialNumber ?? "")
        _sku = State(initialValue: asset.sku ?? "")
        _category = State(initialValue: asset.category ?? "")
        _conditionGrade = State(initialValue: asset.conditionGrade ?? "")
        _isOem = State(initialValue: asset.isOemBool)
        _isRefurbished = State(initialValue: asset.isRefurbishedBool)
        _warrantyMonths = State(initialValue: asset.warrantyMonths.map(String.init) ?? "")
        _notes = State(initialValue: asset.notes ?? "")
    }

    private var categoryChanged: Bool { category != (asset.category ?? "") }
    private var hasSku: Bool { !(asset.sku ?? "").isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identification") {
                    TextField("Serial number", text: $serialNumber)
                    TextField("SKU", text: $sku)
                    TextField("Category", text: $category)
                    if hasSku, categoryChanged {
                        Text("This will update all assets with SKU: \(asset.sku ?? "")")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if !categorySuggestions.isEmpty {
                        Menu("Suggestions") {
                            ForEach(categorySuggestions, id: \.self) { s in
                                Button(s) { category = s }
                            }
                        }.font(.caption)
                    }
                }
                Section("Quality") {
                    Picker("Condition grade", selection: $conditionGrade) {
                        Text("Not set").tag("")
                        Text("A - Excellent").tag("A")
                        Text("B - Good").tag("B")
                        Text("C - Fair").tag("C")
                        Text("D - Poor").tag("D")
                        Text("F - For Parts").tag("F")
                    }
                    Toggle("OEM", isOn: $isOem)
                    Toggle("Refurbished", isOn: $isRefurbished)
                }
                Section("Warranty") {
                    TextField("Warranty months", text: $warrantyMonths)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if let err = viewModel.actionError {
                    Section { Text(err).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Edit Asset")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { viewModel.actionError = nil; dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(viewModel.isMutating)
                }
            }
            .task {
                categorySuggestions = (try? await InventoryService().fetchCategories()) ?? []
            }
        }
    }

    private func save() async {
        var body = UpdateAssetRequest()
        body.name = asset.name  // carried through unchanged (web parity — no visible name field)
        body.serialNumber = serialNumber.isEmpty ? nil : serialNumber
        body.sku = sku.isEmpty ? nil : sku
        body.category = category.isEmpty ? nil : category
        // Always send condition_grade (incl. "" to clear it) — matches web, whose select
        // submits the value directly so choosing "Not set" actually clears the grade.
        body.conditionGrade = conditionGrade
        body.isOem = isOem ? 1 : 0
        body.isRefurbished = isRefurbished ? 1 : 0
        body.warrantyMonths = Int(warrantyMonths)
        body.notes = notes.isEmpty ? nil : notes
        await viewModel.edit(body)
        if viewModel.actionError == nil { dismiss() }
    }
}
