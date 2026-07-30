//
//  CustomerUnlistedItemLeadCard.swift
//  Repair Minder
//
//  Created on 30/07/2026.
//

import SwiftUI

/// Shown instead of CustomerSellNextStepsCard when the enquiry is an
/// unlisted-item lead (CustomerEnquiryDetail.isUnlistedItem) - an item with no
/// catalog price and no staff review yet, such as something submitted through
/// the storefront's "not listed" / custom-quote flow. No label, no button:
/// staff have to look at the item and reply with a price before anything
/// about getting it to us applies.
///
/// Twin of `UnlistedItemLeadCard.tsx` in the web portal - same message.
/// Change one, change the other.
struct CustomerUnlistedItemLeadCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text("We're reviewing this item")
                    .font(.headline)
                Text("We're reviewing this item and will email you a quote shortly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
