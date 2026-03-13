//
//  TierSelectionSheet.swift
//  Repair Minder
//

import SwiftUI

struct TierSelectionSheet: View {
    let productName: String
    let defaultPrice: Double
    let tiers: [QualityTier]
    let onSelect: (_ tierName: String?, _ price: Double) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tiers) { tier in
                        Button {
                            dismiss()
                            onSelect(tier.tier, tier.price ?? defaultPrice)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tier.tier)
                                        .font(.headline)
                                    // Visual hint for aftermarket
                                    if tier.tier.lowercased().contains("aftermarket") {
                                        Text("Third-party component")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Text(CurrencyFormatter.format(tier.price ?? defaultPrice))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Select quality tier")
                }

                Section {
                    Button {
                        dismiss()
                        onSelect(nil, defaultPrice)
                    } label: {
                        HStack {
                            Text("Use default (no tier)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CurrencyFormatter.format(defaultPrice))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(productName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onCancel()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
