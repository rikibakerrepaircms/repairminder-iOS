import SwiftUI

@MainActor
final class GroupEditModel: ObservableObject {
    let groupId: String
    @Published var name: String
    @Published var sku: String
    @Published var category: String
    @Published var subcategory: String
    @Published var manufacturer: String
    @Published var modelNumber: String
    @Published var reorderLevel: String
    @Published var reorderQuantity: String
    @Published var defaultCost: String
    @Published var defaultSellPrice: String
    @Published var preferredSupplierName: String
    @Published var isOem: Bool
    @Published var isRefurbished: Bool
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    private let service: InventoryServing

    // Snapshot of the values the group had on open — used to tell "field was
    // cleared by the user" (should send "" so the backend blanks it) apart
    // from "field was never set" (stays omitted from the request body).
    private let originalSku: String
    private let originalSubcategory: String
    private let originalManufacturer: String
    private let originalModelNumber: String
    private let originalPreferredSupplierName: String

    init(group: InventoryGroup, service: InventoryServing? = nil) {
        self.service = service ?? InventoryService()
        self.groupId = group.id
        self.name = group.name
        self.sku = group.sku ?? ""
        self.category = group.category ?? ""
        self.subcategory = group.subcategory ?? ""
        self.manufacturer = group.manufacturer ?? ""
        self.modelNumber = group.modelNumber ?? ""
        self.reorderLevel = group.reorderLevel.map(String.init) ?? ""
        self.reorderQuantity = group.reorderQuantity.map(String.init) ?? ""
        self.defaultCost = group.defaultCost.map { String(format: "%g", $0) } ?? ""
        self.defaultSellPrice = group.defaultSellPrice.map { String(format: "%g", $0) } ?? ""
        self.preferredSupplierName = group.preferredSupplierName ?? ""
        self.isOem = group.isOemBool
        self.isRefurbished = group.isRefurbishedBool
        self.originalSku = group.sku ?? ""
        self.originalSubcategory = group.subcategory ?? ""
        self.originalManufacturer = group.manufacturer ?? ""
        self.originalModelNumber = group.modelNumber ?? ""
        self.originalPreferredSupplierName = group.preferredSupplierName ?? ""
    }

    /// Empty text -> "" if the field was previously populated (an explicit clear
    /// the backend will honour), or nil if it was never set (nothing to clear).
    private static func clearableValue(original: String, current: String) -> String? {
        if !current.isEmpty { return current }
        if !original.isEmpty { return "" }
        return nil
    }

    /// Pure request builder — split out from `submit()` so it can be unit tested
    /// without going through the async service call.
    func buildRequest() -> GroupFormRequest {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return GroupFormRequest(
            name: trimmed,
            category: category.isEmpty ? "General" : category,   // backend requires non-empty category
            sku: Self.clearableValue(original: originalSku, current: sku),
            subcategory: Self.clearableValue(original: originalSubcategory, current: subcategory),
            manufacturer: Self.clearableValue(original: originalManufacturer, current: manufacturer),
            modelNumber: Self.clearableValue(original: originalModelNumber, current: modelNumber),
            reorderLevel: Int(reorderLevel),
            reorderQuantity: Int(reorderQuantity),
            defaultCost: Double(defaultCost),
            defaultSellPrice: Double(defaultSellPrice),
            preferredSupplierName: Self.clearableValue(original: originalPreferredSupplierName, current: preferredSupplierName),
            isOem: isOem ? 1 : 0,
            isRefurbished: isRefurbished ? 1 : 0)
    }

    func submit() async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Name is required"; return false }
        isSubmitting = true; defer { isSubmitting = false }; errorMessage = nil
        let body = buildRequest()
        do { _ = try await service.updateGroup(id: groupId, body: body); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }
}

struct GroupEditSheet: View {
    @StateObject private var model: GroupEditModel
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(group: InventoryGroup, onSuccess: @escaping () -> Void) {
        _model = StateObject(wrappedValue: GroupEditModel(group: group))
        self.onSuccess = onSuccess
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $model.name).accessibilityIdentifier("group-edit-name")
                    TextField("SKU", text: $model.sku)
                    TextField("Category", text: $model.category)
                    TextField("Subcategory", text: $model.subcategory)
                    TextField("Manufacturer", text: $model.manufacturer)
                    TextField("Model number", text: $model.modelNumber)
                }
                Section("Stock") {
                    TextField("Reorder level", text: $model.reorderLevel).keyboardType(.numberPad)
                    TextField("Reorder quantity", text: $model.reorderQuantity).keyboardType(.numberPad)
                    TextField("Default cost", text: $model.defaultCost).keyboardType(.decimalPad)
                    TextField("Default sell price", text: $model.defaultSellPrice).keyboardType(.decimalPad)
                    TextField("Preferred supplier", text: $model.preferredSupplierName)
                    Toggle("OEM", isOn: $model.isOem)
                    Toggle("Refurbished", isOn: $model.isRefurbished)
                }
                if let e = model.errorMessage { Text(e).foregroundStyle(.red) }
            }
            .navigationTitle("Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { if await model.submit() { onSuccess(); dismiss() } } }
                        .disabled(model.isSubmitting)
                        .accessibilityIdentifier("group-edit-save")
                }
            }
        }
    }
}
