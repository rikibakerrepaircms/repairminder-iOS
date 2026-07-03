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
    }

    func submit() async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Name is required"; return false }
        isSubmitting = true; defer { isSubmitting = false }; errorMessage = nil
        let body = GroupFormRequest(
            name: trimmed,
            category: category.isEmpty ? "General" : category,   // backend requires non-empty category
            sku: sku.isEmpty ? nil : sku,
            subcategory: subcategory.isEmpty ? nil : subcategory,
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            modelNumber: modelNumber.isEmpty ? nil : modelNumber,
            reorderLevel: Int(reorderLevel),
            reorderQuantity: Int(reorderQuantity),
            defaultCost: Double(defaultCost),
            defaultSellPrice: Double(defaultSellPrice),
            preferredSupplierName: preferredSupplierName.isEmpty ? nil : preferredSupplierName,
            isOem: isOem ? 1 : 0,
            isRefurbished: isRefurbished ? 1 : 0)
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
