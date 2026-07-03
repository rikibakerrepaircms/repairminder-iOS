import SwiftUI

@MainActor
final class PromoteSheetModel: ObservableObject {
    let group: InventoryGroup
    @Published var name: String
    @Published var sku: String
    @Published var category: String
    @Published var sellPrice: String
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var skuError: String?
    private let service: InventoryServing

    init(group: InventoryGroup, service: InventoryServing? = nil) {
        self.group = group
        self.service = service ?? InventoryService()
        self.name = group.name
        self.sku = (group.sku?.isEmpty == false) ? "PROD-\(group.sku!)" : ""
        self.category = group.category ?? ""
        self.sellPrice = group.defaultSellPrice.map { String(format: "%g", $0) } ?? ""
    }

    func submit() async -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { errorMessage = "Product name is required"; return false }
        isSubmitting = true; defer { isSubmitting = false }
        errorMessage = nil; skuError = nil
        let req = PromoteGroupRequest(
            groupId: group.id,
            productName: name.trimmingCharacters(in: .whitespaces),
            productSku: sku.isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces),
            productCategory: category.isEmpty ? nil : category,
            defaultSellPrice: Double(sellPrice))
        do {
            _ = try await service.promoteGroup(req)
            return true
        } catch {
            let message = error.localizedDescription
            let is409: Bool
            if case APIError.httpError(let status, _) = error { is409 = (status == 409) } else { is409 = false }
            if is409 || message.lowercased().contains("sku") {
                skuError = "This SKU is already in use. Choose a different one."
            } else {
                errorMessage = message
            }
            return false
        }
    }
}

struct PromoteToProductSheet: View {
    @StateObject private var model: PromoteSheetModel
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(group: InventoryGroup, onSuccess: @escaping () -> Void) {
        _model = StateObject(wrappedValue: PromoteSheetModel(group: group))
        self.onSuccess = onSuccess
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(model.group.name).font(.headline)
                    Text("\(model.group.inStockCount ?? 0) items in stock").font(.caption).foregroundStyle(.secondary)
                    Text("Creates a sellable product backed by this group's stock.").font(.caption).foregroundStyle(.secondary)
                    if GroupActions.alreadyLinked(model.group) {
                        Text("Already linked to \(model.group.linkedProductCount ?? 0) product(s). Creating another shares the same stock.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section {
                    TextField("Product name", text: $model.name).accessibilityIdentifier("promote-name")
                    TextField("SKU", text: $model.sku)
                    if let e = model.skuError { Text(e).font(.caption).foregroundStyle(.red) }
                    TextField("Category", text: $model.category)
                    TextField("Sell price", text: $model.sellPrice).keyboardType(.decimalPad)
                }
                if let e = model.errorMessage { Text(e).foregroundStyle(.red) }
            }
            .navigationTitle("Promote to Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { if await model.submit() { onSuccess(); dismiss() } } }
                        .disabled(model.isSubmitting)
                        .accessibilityIdentifier("promote-create")
                }
            }
        }
    }
}
