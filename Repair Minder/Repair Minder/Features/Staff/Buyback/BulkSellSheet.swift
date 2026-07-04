//
//  BulkSellSheet.swift
//  Repair Minder
//
//  Sell multiple `for_sale` buyback devices together in one order via
//  POST /api/buyback/sell-bulk. Reuses the client/channel field layout and
//  locale-safe price parsing from SellBuybackSheet.
//

import SwiftUI

private enum BulkSaleChannelOption: String, CaseIterable, Identifiable {
    case direct
    case ebay
    case shopify

    var id: String { rawValue }

    var label: String {
        switch self {
        case .direct: return "Direct"
        case .ebay: return "eBay"
        case .shopify: return "Shopify"
        }
    }
}

/// Sells several selected buyback devices in one bulk order. Each item gets
/// its own editable sale price; the client/channel fields are shared across
/// the whole order. Leaving the client fields blank records a walk-in sale.
struct BulkSellSheet: View {
    let items: [BuybackItem]
    let onSell: (BulkSellRequest) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var salePrices: [String: String]
    @State private var saleChannel: BulkSaleChannelOption = .direct
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var clientEmail = ""
    @State private var clientPhone = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(items: [BuybackItem], onSell: @escaping (BulkSellRequest) async -> String?) {
        self.items = items
        self.onSell = onSell
        var prefill: [String: String] = [:]
        for item in items {
            if let price = item.sellPrice {
                prefill[item.id] = String(price)
            }
        }
        _salePrices = State(initialValue: prefill)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.deviceDisplayName.isEmpty ? "Unknown Device" : item.deviceDisplayName)
                                    .font(.subheadline)
                                if let identifier = item.primaryIdentifier {
                                    Text(identifier)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            TextField("Price (£)", text: priceBinding(for: item.id))
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .frame(maxWidth: 100)
                        }
                    }
                } header: {
                    Text("Items (\(items.count))")
                } footer: {
                    Text("Enter a sale price for each item to include it in the bulk order.")
                }

                Section("Sale") {
                    Picker("Channel", selection: $saleChannel) {
                        ForEach(BulkSaleChannelOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }

                Section {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                    TextField("Email", text: $clientEmail)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        #endif
                    TextField("Phone", text: $clientPhone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                } header: {
                    Text("Client (optional)")
                } footer: {
                    Text("Leave blank to record this as a walk-in sale with no linked client.")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Sell \(items.count) Devices")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    sellButton
                }
            }
            .disabled(isSaving)
        }
    }

    private func priceBinding(for id: String) -> Binding<String> {
        Binding(
            get: { salePrices[id] ?? "" },
            set: { salePrices[id] = $0 }
        )
    }

    private var sellButton: some View {
        Button("Sell") {
            Task { await sell() }
        }
        .accessibilityIdentifier("bulk-sell-confirm")
        .disabled(isSaving || items.isEmpty)
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func sell() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        var lineItems: [BulkSellItemRequest] = []
        for item in items {
            let raw = salePrices[item.id] ?? ""
            guard let price = parseDecimal(raw), price >= 0 else {
                errorMessage = "Enter a valid price for every item"
                return
            }
            lineItems.append(BulkSellItemRequest(id: item.id, salePrice: price, platformFee: nil))
        }

        guard !lineItems.isEmpty else {
            errorMessage = "No items to sell"
            return
        }

        let request = BulkSellRequest(
            items: lineItems,
            clientId: nil,
            firstName: nonEmpty(firstName),
            lastName: nonEmpty(lastName),
            clientEmail: nonEmpty(clientEmail),
            clientPhone: nonEmpty(clientPhone),
            noEmail: nil,
            saleChannel: saleChannel.rawValue
        )

        if let error = await onSell(request) {
            errorMessage = error
        } else {
            dismiss()
        }
    }
}
