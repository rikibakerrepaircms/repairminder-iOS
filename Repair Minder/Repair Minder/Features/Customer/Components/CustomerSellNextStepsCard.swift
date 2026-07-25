//
//  CustomerSellNextStepsCard.swift
//  Repair Minder
//
//  Created on 25/07/2026.
//

import SwiftUI

/// The "What happens next" card for a sell enquiry.
///
/// Shown only when the enquiry's `enquiry_kind` is 'sell'. Every other enquiry
/// renders the detail screen without it.
///
/// Copy rules for this file: UK English, hyphens only (no en dash, em dash or
/// minus), "device" rather than "phone" because we also buy tablets, consoles,
/// laptops and watches, and "shop" rather than "workshop".
///
/// This is the twin of `src/components/customer/SellNextStepsCard.tsx` in the web
/// portal. Change the wording in one, change it in the other.
struct CustomerSellNextStepsCard: View {

    /// 'visit' | 'collection' | nil. Nil means the customer never chose a route.
    let fulfilment: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What happens next")
                .font(.headline)

            wipeStep
            fulfilmentStep
            arrivalStep

            // LABEL CTA SLOT. When postage labels exist, the "download your label"
            // button goes here, beside the collection and visit routes above.
            // Nothing in the schema carries a label URL or a tracking number today,
            // so there is deliberately no button - a dead button in front of a
            // paying customer is worse than no button. See labelRequestUrl in
            // worker/src/storefront_handlers.js, still null for the same reason.
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Step 1: Wipe

    private var wipeStep: some View {
        step(icon: "lock.shield", title: "Reset it and remove Find My, before it comes to us") {
            Text("This is the single most common reason a sale stalls. A device that is still signed in stops at an activation lock that only you can clear. Before it reaches us, please sign out of iCloud or your Google account, factory reset the device, and take out the SIM and any memory card.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Link(destination: URL(string: "https://mendmyi.com/blog/how-to-wipe-your-phone-before-selling")!) {
                    Label("How to wipe your device", systemImage: "arrow.up.right.square")
                        .font(.footnote)
                }
                Link(destination: URL(string: "https://support.apple.com/en-gb/109511")!) {
                    Label("Apple: before you sell or trade in", systemImage: "arrow.up.right.square")
                        .font(.footnote)
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Step 2: Getting it to us

    @ViewBuilder
    private var fulfilmentStep: some View {
        switch fulfilment {
        case CustomerFulfilment.collection:
            step(icon: "shippingbox", title: "Your collection slot is a request, not a booking") {
                Text("The day and two-hour window you chose is a request. We will email you to confirm it, or to offer the nearest slot we can make. If the time no longer suits you, just reply to that email and we will rearrange it. Rearranging is free and there is no limit on how many times you can do it. We collect within 5 miles of the shop.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case CustomerFulfilment.visit:
            step(icon: "storefront", title: "Bring it into the shop") {
                Text("Come in during our opening hours. You do not need an appointment, and we will test the device while you wait. Please bring photo ID with you, because we record ID on every device we buy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        default:
            // Nil or anything unrecognised. We say what is true for every route
            // rather than guessing one and promising something nobody agreed to.
            step(icon: "calendar", title: "Getting the device to us") {
                Text("We will be in touch to arrange it with you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Step 3: On arrival

    private var arrivalStep: some View {
        step(icon: "checkmark.seal", title: "What happens when it reaches us") {
            Text("We check the device on the bench, then email you a confirmed offer. You can accept it or reject it. If you accept, we pay out within one working day. If you reject it, we return the device to you free of charge.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Layout

    private func step<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Preview

#Preview("Collection") {
    CustomerSellNextStepsCard(fulfilment: "collection").padding()
}

#Preview("Visit") {
    CustomerSellNextStepsCard(fulfilment: "visit").padding()
}

#Preview("Unknown") {
    CustomerSellNextStepsCard(fulfilment: nil).padding()
}
