//
//  RefurbishmentEditSheet.swift
//  Repair Minder
//
//  Add or edit a refurbishment line item on a buyback device. Backing a
//  single Form for both flows:
//    - Add:    POST /api/buyback/:id/refurbishment   (item_type is required)
//    - Edit:   PATCH /api/buyback/:id/refurbishment/:itemId (item_type is
//              NOT patchable server-side, so it is shown read-only)
//

import SwiftUI

/// Parses a user-entered decimal amount using the current locale (handles
/// locales where `,` is the decimal separator), falling back to a plain
/// `Double(_:)` parse for inputs like a bare ".". Copied from
/// SellBuybackSheet — kept file-local to avoid a cross-file dependency.
private func parseDecimal(_ s: String) -> Double? {
    let t = s.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return nil }
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale.current
    if let n = f.number(from: t) { return n.doubleValue }
    return Double(t)
}

private enum RefurbishmentItemTypeOption: String, CaseIterable, Identifiable {
    case part
    case labor
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .part: return "Part"
        case .labor: return "Labour"
        case .other: return "Other"
        }
    }

    init(rawValueOrDefault: String?) {
        self = RefurbishmentItemTypeOption(rawValue: rawValueOrDefault ?? "") ?? .part
    }
}

/// Adds a new refurbishment item, or edits an existing one, depending on
/// whether `existingItem` is non-nil.
struct RefurbishmentEditSheet: View {
    let existingItem: RefurbishmentItem?
    /// Returns nil on success, an error message otherwise.
    let onSave: (AddRefurbishmentRequest?, UpdateRefurbishmentRequest?) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var itemType: RefurbishmentItemTypeOption
    @State private var description: String
    @State private var unitCost: String
    @State private var quantity: Int
    @State private var partNumber: String
    @State private var supplier: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { existingItem != nil }

    init(
        existingItem: RefurbishmentItem?,
        onSave: @escaping (AddRefurbishmentRequest?, UpdateRefurbishmentRequest?) async -> String?
    ) {
        self.existingItem = existingItem
        self.onSave = onSave

        _itemType = State(initialValue: RefurbishmentItemTypeOption(rawValueOrDefault: existingItem?.itemType))
        _description = State(initialValue: existingItem?.description ?? "")
        _unitCost = State(initialValue: existingItem?.unitCost.map { String($0) } ?? "")
        _quantity = State(initialValue: existingItem?.quantity ?? 1)
        _partNumber = State(initialValue: existingItem?.partNumber ?? "")
        _supplier = State(initialValue: existingItem?.supplier ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    if isEditing {
                        HStack {
                            Text("Type")
                            Spacer()
                            Text(itemType.label)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Type", selection: $itemType) {
                            ForEach(RefurbishmentItemTypeOption.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    }

                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("refurb-description")

                    TextField("Unit cost (£)", text: $unitCost)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .accessibilityIdentifier("refurb-unit-cost")

                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
                        .accessibilityIdentifier("refurb-quantity")
                }

                Section("Optional") {
                    TextField("Part number", text: $partNumber)
                    TextField("Supplier", text: $supplier)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
            }
            .disabled(isSaving)
        }
    }

    private var saveButton: some View {
        Button("Save") {
            Task { await save() }
        }
        .accessibilityIdentifier("refurb-save")
        .disabled(isSaving || trimmedDescription.isEmpty)
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        guard let cost = parseDecimal(unitCost) else {
            errorMessage = "Enter a valid unit cost"
            return
        }

        let result: String?
        if let existingItem {
            // Only send fields the user actually changed, to avoid clobbering
            // server-side values with no-op writes.
            var request = UpdateRefurbishmentRequest()
            if trimmedDescription != (existingItem.description ?? "") {
                request.description = trimmedDescription
            }
            if quantity != (existingItem.quantity ?? 1) {
                request.quantity = quantity
            }
            if cost != existingItem.unitCost {
                request.unitCost = cost
            }
            let newPartNumber = nonEmpty(partNumber)
            if newPartNumber != existingItem.partNumber {
                request.partNumber = newPartNumber
            }
            let newSupplier = nonEmpty(supplier)
            if newSupplier != existingItem.supplier {
                request.supplier = newSupplier
            }
            result = await onSave(nil, request)
        } else {
            let request = AddRefurbishmentRequest(
                itemType: itemType.rawValue,
                description: trimmedDescription,
                unitCost: cost,
                quantity: quantity,
                partNumber: nonEmpty(partNumber),
                supplier: nonEmpty(supplier)
            )
            result = await onSave(request, nil)
        }

        if let error = result {
            errorMessage = error
        } else {
            dismiss()
        }
    }
}
