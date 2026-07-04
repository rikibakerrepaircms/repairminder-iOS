//
//  BuybackPurchaseEditSheet.swift
//  Repair Minder
//
//  Edit purchase info (date/amount/payment method/reference/notes) on a
//  buyback device. Phase 3 — buyback lifecycle.
//

import SwiftUI

private let purchaseDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter
}()

/// Edits `purchase_date`, `purchase_amount`, `purchase_payment_method`,
/// `purchase_order_reference`, and `purchase_notes` via PATCH /api/buyback/:id.
struct BuybackPurchaseEditSheet: View {
    let detail: BuybackDetail
    let onSave: ([String: AnyEncodable]) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var purchaseDate: Date
    @State private var amount: String
    @State private var paymentMethod: String
    @State private var reference: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(detail: BuybackDetail, onSave: @escaping ([String: AnyEncodable]) async -> String?) {
        self.detail = detail
        self.onSave = onSave
        _purchaseDate = State(initialValue: detail.purchaseDate.flatMap { purchaseDateFormatter.date(from: $0) } ?? Date())
        _amount = State(initialValue: detail.purchaseAmount.map { String($0) } ?? "")
        _paymentMethod = State(initialValue: detail.purchasePaymentMethod ?? "")
        _reference = State(initialValue: detail.purchaseOrderReference ?? "")
        _notes = State(initialValue: detail.purchaseNotes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Purchase") {
                    DatePicker("Date", selection: $purchaseDate, displayedComponents: .date)
                    TextField("Amount (£)", text: $amount)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Payment method", text: $paymentMethod)
                    TextField("Reference", text: $reference)
                }

                Section("Notes") {
                    TextField("Purchase notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Purchase")
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
        .accessibilityIdentifier("buyback-purchase-save")
        .disabled(isSaving)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        var fields: [String: AnyEncodable] = [
            "purchase_date": AnyEncodable(purchaseDateFormatter.string(from: purchaseDate)),
            "purchase_payment_method": AnyEncodable(paymentMethod),
            "purchase_order_reference": AnyEncodable(reference),
            "purchase_notes": AnyEncodable(notes),
        ]
        if let value = Double(amount) {
            fields["purchase_amount"] = AnyEncodable(value)
        }

        if let error = await onSave(fields) {
            errorMessage = error
        } else {
            dismiss()
        }
    }
}
