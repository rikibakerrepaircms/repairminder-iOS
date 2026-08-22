//
//  CustomerSellDeclarationCard.swift
//  Repair Minder
//

import SwiftUI

/// The seller's own answers, shown back to them BEFORE the device leaves them.
///
/// The Apple twin of `SellDeclarationCard.tsx`. Change the wording there, change it
/// here too.
///
/// Until migration 0504 these answers lived only in the free text of the staff note,
/// which the portal filters out - so a seller could not see what they had told us.
/// Sell order 100002861 ticked "Brand new - factory sealed, never activated, no
/// iCloud / Google Account lock" and wrote in the same submission that they had
/// forgotten the pattern and needed the device factory reset.
///
/// So this is not a receipt. It is a prompt to check, and it carries the invitation
/// to re-quote NOW rather than after the device has travelled - cheaper for everyone
/// than a rejected offer and a return parcel.
///
/// Renders nothing when there is nothing recorded. Never a card of dashes.
struct CustomerSellDeclarationCard: View {
    let declaration: SellDeclaration

    /// Ownership is three-state. Only an explicit `true` earns a tick here - nil
    /// means the question was never asked, and listing it would remind them of
    /// something they were never shown.
    private var ticked: [String] {
        (declaration.ownershipConfirmed == true ? [SellDeclaration.ownershipStatement] : [])
            + declaration.confirmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("What you told us", systemImage: "checklist")
                .font(.headline)

            if let condition = declaration.condition {
                field("Condition you picked") {
                    Text(condition).font(.subheadline)
                }
            }

            if let price = declaration.quotedPrice {
                field("Your quote") {
                    HStack(spacing: 4) {
                        Text(price).font(.subheadline.weight(.semibold))
                        // Only when we actually promised a window. A hold we never
                        // offered must not appear as one we did.
                        if let days = declaration.priceLockDays {
                            Text("- held for \(days) days")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !ticked.isEmpty {
                field("You confirmed") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(ticked, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                                Text(item).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Shown to the seller too, not just to staff. An unticked criterion is
            // not an accusation - it is what we will be looking at, and saying so is
            // what lets them answer it now rather than be surprised by the offer.
            if !declaration.notConfirmed.isEmpty {
                field("You did not confirm") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(declaration.notConfirmed, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.dashed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Text("Please check this against the device in front of you. If anything is not right, tell us on this order before you send it and we will re-quote it now - that is quicker and cheaper for you than an offer you turn down and a device posted back.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}
