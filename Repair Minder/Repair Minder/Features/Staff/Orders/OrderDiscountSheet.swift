//
//  OrderDiscountSheet.swift
//  Repair Minder
//
//  Sets or clears a whole-order discount via PATCH /api/orders/:id/discount.
//  Percent and Amount are mutually exclusive (backend XOR rule); a reason is
//  required whenever a discount is applied. Follows the same
//  `(Request) async -> String?` sheet convention as OrderCloseOutSheets.swift.
//

import SwiftUI

/// Discount kind for a whole-order discount. Percent and Amount are mutually
/// exclusive per the backend's XOR validation rule.
private enum OrderDiscountKind: String, CaseIterable, Identifiable {
    case none
    case percent
    case amount

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .percent: return "Percent"
        case .amount: return "Amount"
        }
    }
}

struct OrderDiscountSheet: View {
    let order: Order
    let onSave: (OrderDiscountRequest) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var discountKind: OrderDiscountKind
    @State private var valueText: String
    @State private var reasonText: String
    @State private var busy = false
    @State private var errorText: String?

    init(order: Order, onSave: @escaping (OrderDiscountRequest) async -> String?) {
        self.order = order
        self.onSave = onSave

        if let percent = order.globalDiscountPercent, percent > 0 {
            _discountKind = State(initialValue: .percent)
            _valueText = State(initialValue: formatDecimalForEditing(percent))
        } else if let amount = order.globalDiscountAmount, amount > 0 {
            _discountKind = State(initialValue: .amount)
            _valueText = State(initialValue: formatDecimalForEditing(amount))
        } else {
            _discountKind = State(initialValue: .none)
            _valueText = State(initialValue: "")
        }
        _reasonText = State(initialValue: order.globalDiscountReason ?? "")
    }

    // MARK: - Validation

    private var parsedValue: Double? {
        parseDecimal(valueText)
    }

    private var reasonMissing: Bool {
        discountKind != .none && reasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var percentOutOfRange: Bool {
        guard discountKind == .percent, let value = parsedValue else { return false }
        return value < 0 || value > 100
    }

    private var isValid: Bool {
        guard discountKind != .none else { return true }
        guard let value = parsedValue, value >= 0 else { return false }
        if discountKind == .percent && value > 100 { return false }
        if reasonMissing { return false }
        return true
    }

    private var hasExistingDiscount: Bool {
        (order.globalDiscountPercent ?? 0) > 0 || (order.globalDiscountAmount ?? 0) > 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Discount") {
                    Picker("Type", selection: $discountKind) {
                        ForEach(OrderDiscountKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if discountKind != .none {
                        TextField(
                            discountKind == .percent ? "Percent off (e.g. 10)" : "Amount off (\u{00A3})",
                            text: $valueText
                        )
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .accessibilityIdentifier("order-discount-value")

                        TextField("Reason", text: $reasonText)
                            .accessibilityIdentifier("order-discount-reason")

                        if reasonMissing {
                            Text("A reason is required when a discount is applied.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        if percentOutOfRange {
                            Text("Percent must be between 0 and 100.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text("Saving with \"None\" clears any existing whole-order discount.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorText {
                    Text(errorText).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle(hasExistingDiscount ? "Edit Discount" : "Add Discount")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { errorText = nil; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(busy || !isValid)
                    .accessibilityIdentifier("order-discount-save")
                }
            }
        }
    }

    // MARK: - Save

    private func save() async {
        guard isValid else { return }
        busy = true
        defer { busy = false }

        var request = OrderDiscountRequest()
        if discountKind != .none, let value = parsedValue {
            if discountKind == .percent {
                request.discountPercent = value
            } else {
                request.discountAmount = value
            }
            let reason = reasonText.trimmingCharacters(in: .whitespacesAndNewlines)
            request.discountReason = reason.isEmpty ? nil : reason
        }

        let err = await onSave(request)
        if err == nil {
            errorText = nil
            dismiss()
        } else {
            errorText = err
        }
    }
}
