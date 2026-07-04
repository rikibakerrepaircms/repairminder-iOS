//
//  ListingEditSheet.swift
//  Repair Minder
//
//  Edits the AI-generated (or manually authored) marketplace listing fields
//  on a buyback device: `listing_title`, `listing_short_description`,
//  `sell_price`, `listing_condition`. PATCH /api/buyback/:id via
//  BuybackDetailViewModel.updateListing(fields:).
//

import SwiftUI

/// Common storefront condition grades. The field is free-text server-side,
/// so an "Other" escape hatch (plain TextField) is offered alongside the picker.
private enum ListingConditionOption: String, CaseIterable, Identifiable {
    case new
    case likeNew = "like_new"
    case good
    case fair
    case poor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new: return "New"
        case .likeNew: return "Like New"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
}

/// `parseDecimal` / `formatDecimalForEditing` are defined in SellBuybackSheet.swift
/// (internal, shared across the Buyback feature).
struct ListingEditSheet: View {
    let detail: BuybackDetail
    let onSave: ([String: AnyEncodable]) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var shortDescription: String
    @State private var sellPrice: String
    @State private var conditionOption: ListingConditionOption?
    @State private var customCondition: String
    @State private var useCustomCondition: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(detail: BuybackDetail, onSave: @escaping ([String: AnyEncodable]) async -> String?) {
        self.detail = detail
        self.onSave = onSave

        _title = State(initialValue: detail.listingTitle ?? "")
        _shortDescription = State(initialValue: detail.listingShortDescription ?? "")
        _sellPrice = State(initialValue: detail.sellPrice.map { formatDecimalForEditing($0) } ?? "")

        let existingCondition = detail.listingCondition ?? ""
        if let matched = ListingConditionOption.allCases.first(where: { $0.rawValue == existingCondition }) {
            _conditionOption = State(initialValue: matched)
            _customCondition = State(initialValue: "")
            _useCustomCondition = State(initialValue: false)
        } else if !existingCondition.isEmpty {
            _conditionOption = State(initialValue: nil)
            _customCondition = State(initialValue: existingCondition)
            _useCustomCondition = State(initialValue: true)
        } else {
            _conditionOption = State(initialValue: nil)
            _customCondition = State(initialValue: "")
            _useCustomCondition = State(initialValue: false)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Listing") {
                    TextField("Title", text: $title)
                    TextField("Short description", text: $shortDescription, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Sell price (£)", text: $sellPrice)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }

                Section("Condition") {
                    Picker("Condition", selection: $conditionOption) {
                        Text("Select…").tag(ListingConditionOption?.none)
                        ForEach(ListingConditionOption.allCases) { option in
                            Text(option.label).tag(ListingConditionOption?.some(option))
                        }
                    }
                    .onChange(of: conditionOption) { _, newValue in
                        if newValue != nil { useCustomCondition = false }
                    }

                    Toggle("Custom condition text", isOn: $useCustomCondition)
                        .onChange(of: useCustomCondition) { _, newValue in
                            if newValue { conditionOption = nil }
                        }

                    if useCustomCondition {
                        TextField("Condition", text: $customCondition)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Listing")
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
        .accessibilityIdentifier("buyback-listing-save")
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

        if let value = nonEmpty(title) {
            fields["listing_title"] = AnyEncodable(value)
        }
        if let value = nonEmpty(shortDescription) {
            fields["listing_short_description"] = AnyEncodable(value)
        }

        let trimmedPrice = sellPrice.trimmingCharacters(in: .whitespaces)
        if !trimmedPrice.isEmpty {
            guard let value = parseDecimal(sellPrice) else {
                errorMessage = "Enter a valid amount"
                return
            }
            fields["sell_price"] = AnyEncodable(value)
        }

        if useCustomCondition, let value = nonEmpty(customCondition) {
            fields["listing_condition"] = AnyEncodable(value)
        } else if let condition = conditionOption {
            fields["listing_condition"] = AnyEncodable(condition.rawValue)
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
