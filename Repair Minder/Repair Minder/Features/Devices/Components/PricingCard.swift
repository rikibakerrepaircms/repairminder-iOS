//
//  PricingCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct PricingCard: View {
    let price: Decimal?
    @Binding var editedPrice: String
    @Binding var isEditing: Bool
    let isSaving: Bool
    let onSave: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Pricing", systemImage: "sterlingsign.circle.fill")
                    .font(.headline)

                Spacer()

                if !isEditing {
                    Button("Edit") {
                        isEditing = true
                        if let price = price {
                            editedPrice = "\(price)"
                        }
                        isFocused = true
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline)
                }
            }

            if isEditing {
                HStack(spacing: 12) {
                    HStack {
                        Text("£")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        TextField("0.00", text: $editedPrice)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .keyboardType(.decimalPad)
                            .focused($isFocused)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        onSave()
                        isFocused = false
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .fontWeight(.bold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || editedPrice.isEmpty)

                    Button {
                        isEditing = false
                        if let price = price {
                            editedPrice = "\(price)"
                        } else {
                            editedPrice = ""
                        }
                        isFocused = false
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.bold)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isSaving)
                }
            } else {
                HStack {
                    if let price = price {
                        Text(formatCurrency(price))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    } else {
                        Text("No price set")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: value as NSDecimalNumber) ?? "£0"
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var editedPrice = ""
        @State private var isEditing = false

        var body: some View {
            VStack(spacing: 20) {
                PricingCard(
                    price: 149.99,
                    editedPrice: $editedPrice,
                    isEditing: $isEditing,
                    isSaving: false,
                    onSave: {}
                )

                PricingCard(
                    price: nil,
                    editedPrice: .constant(""),
                    isEditing: .constant(false),
                    isSaving: false,
                    onSave: {}
                )

                PricingCard(
                    price: 149.99,
                    editedPrice: .constant("175.00"),
                    isEditing: .constant(true),
                    isSaving: false,
                    onSave: {}
                )

                PricingCard(
                    price: 149.99,
                    editedPrice: .constant("175.00"),
                    isEditing: .constant(true),
                    isSaving: true,
                    onSave: {}
                )
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}
