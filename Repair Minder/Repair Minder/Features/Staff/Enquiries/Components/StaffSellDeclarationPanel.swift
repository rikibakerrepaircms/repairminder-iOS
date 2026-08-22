//
//  StaffSellDeclarationPanel.swift
//  Repair Minder
//

import SwiftUI

/// What the seller declared, as FIELDS on the staff ticket.
///
/// The Apple twin of `SellDeclarationPanel.tsx`. All of this was already on the
/// ticket - as a paragraph, inside the storefront note, where nothing can be scanned
/// and nothing can be checked. Sell order 100002861 declared "Brand new - factory
/// sealed, never activated, no iCloud / Google Account lock" three lines above a
/// customer note saying they had forgotten the pattern and needed the device factory
/// reset. Read as prose at 23:21 that contradiction is easy to miss; read as a grade
/// next to a note, it is not.
///
/// The not-confirmed list is the part staff act on: it is the checklist of what to
/// look at when the device lands, so it is the only part that gets the amber
/// treatment used elsewhere for things needing a human.
struct StaffSellDeclarationPanel: View {
    let declaration: SellDeclaration

    /// Three states, never two. `nil` is "the storefront never asked", true of every
    /// ticket before the column existed - rendering that as "NOT confirmed" would
    /// flag hundreds of historic tickets and teach staff to ignore the field.
    private var ownership: (label: String, color: Color) {
        switch declaration.ownershipConfirmed {
        case .some(true):  return ("Confirmed", .green)
        case .some(false): return ("NOT confirmed - check before buying", .red)
        case nil:          return ("Not asked", .secondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What the seller declared", systemImage: "checklist")
                .font(.headline)

            if let condition = declaration.condition {
                field("Condition picked") { Text(condition).font(.subheadline) }
            }

            if let price = declaration.quotedPrice {
                field("Quoted") {
                    HStack(spacing: 4) {
                        Text(price).font(.subheadline.weight(.semibold))
                        if let days = declaration.priceLockDays {
                            Text("- held \(days) days").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            field("Ownership") {
                Text(ownership.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ownership.color)
            }

            if !declaration.confirmed.isEmpty {
                field("Seller confirmed") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(declaration.confirmed, id: \.self) { item in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.green)
                                Text(item).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !declaration.notConfirmed.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Seller did NOT confirm - check on the bench", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    ForEach(declaration.notConfirmed, id: \.self) { item in
                        Text(item).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}
