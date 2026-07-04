//
//  SellBuybackSheet.swift
//  Repair Minder
//
//  Sell a buyback device via POST /api/buyback/:id/sell. Phase 3 — buyback
//  lifecycle. Only shown when the device is `for_sale`.
//

import SwiftUI

private enum SaleChannelOption: String, CaseIterable, Identifiable {
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

/// Sells a buyback device. Client fields are optional — leaving them blank
/// records a walk-in sale with no linked client.
struct SellBuybackSheet: View {
    let detail: BuybackDetail
    let onSell: (SellBuybackRequest) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var salePrice: String
    @State private var saleChannel: SaleChannelOption = .direct
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var clientEmail = ""
    @State private var clientPhone = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(detail: BuybackDetail, onSell: @escaping (SellBuybackRequest) async -> String?) {
        self.detail = detail
        self.onSell = onSell
        let prefill = detail.sellPrice ?? detail.saleAmount
        _salePrice = State(initialValue: prefill.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sale") {
                    TextField("Sale price (£)", text: $salePrice)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Picker("Channel", selection: $saleChannel) {
                        ForEach(SaleChannelOption.allCases) { option in
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
            .navigationTitle("Sell Device")
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

    private var sellButton: some View {
        Button("Sell") {
            Task { await sell() }
        }
        .accessibilityIdentifier("buyback-sell-confirm")
        .disabled(isSaving)
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func sell() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let request = SellBuybackRequest(
            salePrice: Double(salePrice),
            locationId: nil,
            saleChannel: saleChannel.rawValue,
            clientId: nil,
            firstName: nonEmpty(firstName),
            lastName: nonEmpty(lastName),
            clientEmail: nonEmpty(clientEmail),
            clientPhone: nonEmpty(clientPhone),
            noEmail: nil
        )

        if let error = await onSell(request) {
            errorMessage = error
        } else {
            dismiss()
        }
    }
}
