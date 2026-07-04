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

// `parseDecimal` is defined in SellBuybackSheet.swift (internal, shared
// across the Buyback feature).

/// Edits `purchase_date`, `purchase_amount`, `purchase_payment_method`,
/// `purchase_order_reference`, and `purchase_notes` via PATCH /api/buyback/:id.
struct BuybackPurchaseEditSheet: View {
    let detail: BuybackDetail
    let onSave: ([String: AnyEncodable]) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var purchaseDate: Date
    /// Whether `detail.purchaseDate` parsed successfully on init. When false,
    /// `purchaseDate` is a placeholder (today) and must NOT be sent to the
    /// server as a side effect of a failed prefill.
    @State private var dateWasPrefilled: Bool
    @State private var amount: String
    @State private var paymentMethod: String
    @State private var reference: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(detail: BuybackDetail, onSave: @escaping ([String: AnyEncodable]) async -> String?) {
        self.detail = detail
        self.onSave = onSave

        var parsedDate: Date?
        if let raw = detail.purchaseDate {
            if let d = purchaseDateFormatter.date(from: raw) {
                parsedDate = d
            } else if let d = ISO8601DateFormatter().date(from: raw) {
                parsedDate = d
            } else if raw.count >= 10, let d = purchaseDateFormatter.date(from: String(raw.prefix(10))) {
                parsedDate = d
            }
        }
        _purchaseDate = State(initialValue: parsedDate ?? Date())
        _dateWasPrefilled = State(initialValue: parsedDate != nil)

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
                        .onChange(of: purchaseDate) { _, _ in dateWasPrefilled = true }
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

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        var fields: [String: AnyEncodable] = [:]

        let trimmedAmount = amount.trimmingCharacters(in: .whitespaces)
        if !trimmedAmount.isEmpty {
            guard let value = parseDecimal(amount) else {
                errorMessage = "Enter a valid amount"
                return
            }
            fields["purchase_amount"] = AnyEncodable(value)
        }

        if let method = nonEmpty(paymentMethod) {
            fields["purchase_payment_method"] = AnyEncodable(method)
        }
        if let ref = nonEmpty(reference) {
            fields["purchase_order_reference"] = AnyEncodable(ref)
        }
        if let noteText = nonEmpty(notes) {
            fields["purchase_notes"] = AnyEncodable(noteText)
        }
        // Only send purchase_date when the prefill actually parsed (or the
        // user has touched the picker since) — never invent "today" as a
        // side effect of an unparseable server value.
        if dateWasPrefilled {
            fields["purchase_date"] = AnyEncodable(purchaseDateFormatter.string(from: purchaseDate))
        }

        guard !fields.isEmpty else {
            errorMessage = "No changes to save"
            return
        }

        if let error = await onSave(fields) {
            errorMessage = error
        } else {
            dismiss()
        }
    }
}
