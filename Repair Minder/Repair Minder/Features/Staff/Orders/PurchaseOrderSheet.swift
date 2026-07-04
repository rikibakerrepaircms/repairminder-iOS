//
//  PurchaseOrderSheet.swift
//  Repair Minder
//
//  Edits an order's customer purchase order reference/value via
//  PUT /api/orders/:id/purchase-order. Follows the same
//  `(Request) async -> String?` sheet convention as OrderDiscountSheet.
//

import SwiftUI

struct PurchaseOrderSheet: View {
    let order: Order
    let onSave: (PurchaseOrderRequest) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var poReference: String
    @State private var poValueText: String
    @State private var busy = false
    @State private var errorText: String?

    init(order: Order, onSave: @escaping (PurchaseOrderRequest) async -> String?) {
        self.order = order
        self.onSave = onSave
        _poReference = State(initialValue: order.customerPoReference ?? "")
        _poValueText = State(initialValue: order.customerPoValue.map(formatDecimalForEditing) ?? "")
    }

    // MARK: - Validation

    private var parsedValue: Double? {
        parseDecimal(poValueText)
    }

    private var isValid: Bool {
        let trimmed = poValueText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        guard let value = parsedValue else { return false }
        return value >= 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Purchase Order") {
                    TextField("PO reference", text: $poReference)
                        .accessibilityIdentifier("po-reference")

                    TextField("PO value (\u{00A3})", text: $poValueText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .accessibilityIdentifier("po-value")

                    if !isValid {
                        Text("Enter a valid, non-negative amount.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let errorText {
                    Text(errorText).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Purchase Order")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(busy || !isValid)
                    .accessibilityIdentifier("po-save")
                }
            }
            .disabled(busy)
        }
    }

    // MARK: - Save

    private func save() async {
        guard isValid else { return }
        busy = true
        defer { busy = false }

        let trimmedRef = poReference.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = PurchaseOrderRequest(
            poReference: trimmedRef.isEmpty ? nil : trimmedRef,
            poValue: parsedValue
        )

        if let error = await onSave(request) {
            errorText = error
        } else {
            errorText = nil
            dismiss()
        }
    }
}
