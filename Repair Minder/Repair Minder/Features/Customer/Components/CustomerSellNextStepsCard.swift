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

    let ticketId: String

    /// 'visit' | 'collection' | 'doorstep' | nil, where 'collection' is the POSTAL
    /// route and 'doorstep' is the one where we come to them. Nil means the
    /// customer never chose a route.
    let fulfilment: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What happens next")
                .font(.headline)

            wipeStep
            fulfilmentStep
            CustomerReturnLabelStep(ticketId: ticketId, fulfilment: fulfilment)
            CustomerPackagingStep(ticketId: ticketId)
            arrivalStep
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

            Text("We check Find My and run a blacklist check on every device the moment it arrives. If either one stops us, we cannot buy it and we will get in touch - so it is worth doing this properly now rather than having the device sent back to you.")
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
        case CustomerFulfilment.doorstep:
            step(icon: "shippingbox", title: "Your collection slot is a request, not a booking") {
                Text("The day and two-hour window you chose is a request. We will email you to confirm it, or to offer the nearest slot we can make. If the time no longer suits you, just reply to that email and we will rearrange it. Rearranging is free and there is no limit on how many times you can do it. We collect within 5 miles of the shop.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case CustomerFulfilment.collection:
            // The POSTAL route renders nothing here on purpose. The return-label
            // step immediately below IS the postal step - it says the same thing
            // and carries the button that does it, so a block here only made the
            // customer read the same instruction twice in a row. This case used to
            // render the doorstep copy above, promising a van to someone who had
            // asked for a postage label.
            EmptyView()

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

    // A walk-in is tested at the counter while they wait - the step above promises
    // exactly that - so emailing them a confirmed offer and returning the device by
    // post describes a visit that never happened. They are standing in front of us.
    private var arrivalStep: some View {
        let isVisit = fulfilment == CustomerFulfilment.visit
        return step(
            icon: "checkmark.seal",
            title: isVisit ? "What happens at the counter" : "What happens when it reaches us"
        ) {
            Text(isVisit
                 ? "We check the device on the bench while you wait, then give you a firm offer there and then. If you accept it we pay you the same day. If you would rather not, you take the device home with you and there is nothing to pay."
                 : "We check the device on the bench, then email you a confirmed offer. You can accept it or reject it. If you accept, we pay out within one working day. If you reject it, we return the device to you free of charge.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Said here as well as in the wipe step, because the two land at different
            // moments: up there it is a job to do before posting, here it is what will
            // actually happen to the device.
            Text("Every device gets a Find My check and a blacklist check on arrival. A device still locked to an account, or reported lost or stolen, is one we cannot buy.")
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

#Preview("Collection (postal)") {
    CustomerSellNextStepsCard(ticketId: "preview-ticket-id", fulfilment: "collection").padding()
}

#Preview("Doorstep") {
    CustomerSellNextStepsCard(ticketId: "preview-ticket-id", fulfilment: "doorstep").padding()
}

#Preview("Visit") {
    CustomerSellNextStepsCard(ticketId: "preview-ticket-id", fulfilment: "visit").padding()
}

#Preview("Unknown") {
    CustomerSellNextStepsCard(ticketId: "preview-ticket-id", fulfilment: nil).padding()
}
