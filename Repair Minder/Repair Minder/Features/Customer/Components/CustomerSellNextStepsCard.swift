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
/// Finding the shop is NOT this card's job. The address, opening hours,
/// open/closed countdown and directions live in `CustomerShopVisitCard` above this
/// one, on EVERY sell route rather than only on a walk-in - the confirmation email
/// has always given the address to everyone, and this card's job is what happens
/// next, not where we are.
///
/// So both ways of getting the device to us are permanently on the screen: the shop
/// card above, and the return-label step below. The one exception is the POSTAL
/// route, where the label is their primary route and is minted at order time -
/// there the "rather post it?" prompt is never reached, because offering it to
/// someone already posting reads as not having taken in what they picked.
/// buildSellOrderConfirmationEmail withholds the same line for the same reason
/// (`stepOneIsPostal`).
///
/// This is the twin of `src/components/customer/SellNextStepsCard.tsx` in the web
/// portal. Change the wording in one, change it in the other.
struct CustomerSellNextStepsCard: View {

    let ticketId: String

    /// 'visit' | 'collection' | 'doorstep' | nil, where 'collection' is the POSTAL
    /// route and 'doorstep' is the one where we come to them. Nil means the
    /// customer never chose a route.
    let fulfilment: String?

    /// Set by the label step once it knows whether a label exists, so the packaging
    /// step below can be withheld until posting is actually in play. See
    /// `packagingApplies`.
    @State private var hasLabel = false

    /// PACKAGING IS A POSTAL CONCEPT.
    ///
    /// The jiffy bag exists to carry a device to us in the post, and asking for one
    /// puts a chargeable Tracked 24 parcel in front of a staff member to fulfil.
    /// Offering it to someone who told us they are walking into the shop asks about
    /// a journey they are not making, and can end with us posting packaging to a
    /// seller who turns up at the counter anyway.
    ///
    /// So it shows on the POSTAL route, and on any route where a label now exists -
    /// a walk-in who pressed "Ask for a postage label" HAS moved to posting it, and
    /// at that point the question is a fair one. Twin of `packagingApplies` in
    /// `SellNextStepsCard.tsx`.
    private var packagingApplies: Bool {
        fulfilment == CustomerFulfilment.collection || hasLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What happens next")
                .font(.headline)

            wipeStep
            fulfilmentStep
            CustomerReturnLabelStep(ticketId: ticketId, fulfilment: fulfilment, hasLabel: $hasLabel)
            if packagingApplies {
                CustomerPackagingStep(ticketId: ticketId)
            }
            arrivalStep
            // AFTER arrivalStep, which is the one promising "a confirmed offer" -
            // this is what that sentence leaves out.
            estimateStep
            // LAST, next to being paid, because that is the moment it bites: we
            // cannot complete the purchase without it. Shown on every route.
            idStep
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
                // The seller picks a DAY and a HALF DAY - the storefront asks
                // "Morning or afternoon?" and the enum is SLOT_WINDOWS =
                // ['morning', 'afternoon']. The two-hour window is what WE offer
                // back, and this used to tell them they had chosen one.
                Text("The day and half day you chose is a request, not a booking. We will email you a two-hour window to confirm it, or offer the nearest one we can make. If it no longer suits you, just reply to that email and we will rearrange it. Rearranging is free and there is no limit on how many times you can do it. We collect within 5 miles of the shop.")
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
                // The address, the hours and the directions are NOT here any
                // more. They are the "Visit us" card at the top of the screen
                // (CustomerShopVisitCard), so that a walk-in sees where we are and
                // whether we are open before they read an activation-lock warning -
                // the same slot the doorstep route's own card occupies. This step
                // keeps only what it is for: what to do when you get here.
                // The REASON is no longer given here. It is given in full, with the
                // GOV.UK citation, by idStep below - and that step shows on EVERY
                // route, where this line only ever reached a walk-in. Proof of
                // address is now named too: the self-billed purchase invoice HMRC
                // requires has to carry the seller's ADDRESS, and a passport does
                // not have one on it. Twin of SellNextStepsCard.tsx.
                Text("Come in during our opening hours. You do not need an appointment, and we will test the device while you wait. Bring photo ID and a proof of address with you - there is nothing to send us beforehand.")
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

    // MARK: - Step 5: The estimate is not the offer

    /// Why the confirmed offer can land under the estimate.
    ///
    /// Deliberately BEFORE the device is sent. The same four points already exist on
    /// the order screen's device card, but a postal seller does not reach that until
    /// the handset is on our bench - long past the moment they could have checked it
    /// against the grade they picked, or told us they had picked wrong. Sell order
    /// 100002861 chose "Brand new - factory sealed, never activated" and then wrote in
    /// the notes that they were locked out of the phone.
    ///
    /// Shown on every route: a walk-in can be told a different figure across the
    /// counter just as easily as a postal seller can read one in an email.
    ///
    /// Word for word with `EstimateStep` in SellNextStepsCard.tsx and with
    /// /sell-my-phone/how-it-works. Change one, change all three.
    private var estimateStep: some View {
        step(icon: "tag", title: "Your quote is an estimate until we test it") {
            Text("If the device does not match the condition you picked, or it turns out to be locked to an account, the figure can move. Worth a second look before you send it - and if anything is different from what you chose, just tell us on this order and we will re-quote it now rather than after it has travelled.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Self.estimatePoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    static let estimatePoints = [
        "The estimate came from a form. The offer comes from the device itself.",
        "An aftermarket screen, a battery below 90 per cent, or a cheap repair from a year ago all change what the handset is worth to the next owner.",
        "Grading is fine-grained. A small scratch or dent is sometimes enough to move a device from excellent to good.",
        "If it changes, the email says what changed and by how much. We would rather hold a price than lose a sale over a few pounds.",
    ]

    // MARK: - Layout

    // MARK: - Step 6: Name, address and ID

    /// Why we will ask for a name, an address and ID, on EVERY route.
    ///
    /// Buyback order 100002862 is why this exists. A walk-in seller was quoted, then
    /// asked - with no reason attached - to "send over a form of ID so we can complete
    /// the purchase". They replied "Scam!!!", which was a fair reading: the only ask
    /// anything had told them to expect was their bank details. The explanation existed
    /// on mendmyi.com and in the visit branch of `fulfilmentStep`, and they had passed
    /// through neither.
    ///
    /// WHAT WE MAY NOT SAY: no statute requires photo ID. Section 6.2 of the tertiary
    /// legislation lists the seller's name and address - not identity documents - and a
    /// seller who follows the link we just handed them will notice. ID is framed here as
    /// how we verify what the law does require. Never as a requirement in its own right.
    ///
    /// Twin of `IdRequirementCard.tsx`, whose companion `idRequirement.ts` is the
    /// canonical copy and carries the full reasoning. Change one, change both.
    private var idStep: some View {
        step(icon: "person.text.rectangle", title: "Have your ID ready") {
            Text("Before we can pay you we have to record your name and address and check them against photo ID and a proof of address. HMRC requires it on every second-hand purchase a business makes from a private seller, so it applies whichever way your device reaches us.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Riki, 2026-08-22: "we are also happy for them to show us in store rather
            // than sending an electronic copy." A walk-in must not be sent away to
            // photograph a passport for a counter they are already standing at.
            Text(fulfilment == CustomerFulfilment.visit
                 ? "Just bring them with you and show us at the counter - there is nothing to send beforehand. A photocard driving licence showing your current address covers both on its own."
                 : "Send a photo on your order, or reply to any of our emails with it attached. A phone photo is fine as long as the details are readable. A photocard driving licence showing your current address covers both on its own.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Link(destination: URL(string: "https://www.gov.uk/guidance/vat-tertiary-legislation/margin-schemes")!) {
                Label("Why we have to: GOV.UK, VAT margin schemes, section 6.2", systemImage: "arrow.up.right.square")
                    .font(.footnote)
            }
            .padding(.top, 2)
        }
    }

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
