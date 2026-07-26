//
//  CustomerRepairNextStepsCard.swift
//  Repair Minder
//
//  Created on 26/07/2026.
//

import SwiftUI

/// The "What happens next" card for a repair order.
///
/// The twin of `CustomerSellNextStepsCard`, not a mode of it. The label and
/// packaging steps are shared because that is the same parcel; everything
/// else is the inverse. A seller wipes the device because we are buying it.
/// A repair customer must NOT - we have to power it on and test it after the
/// repair.
///
/// Copy rules: UK English, hyphens only (no en dash, em dash or minus),
/// "device" rather than "phone", "shop" rather than "workshop".
///
/// This is the twin of `src/components/customer/RepairNextStepsCard.tsx` in
/// the web portal. Change the wording in one, change it in the other.
struct CustomerRepairNextStepsCard: View {

    let ticketId: String

    /// 'visit' | 'collection' | 'doorstep' | nil, where 'collection' is the POSTAL
    /// route and 'doorstep' is the one where we come to them. Nil means the
    /// customer never chose a route.
    let fulfilment: String?

    /// Set by the label step once it knows whether a label exists, so the packaging
    /// step below can be withheld until posting is actually in play. See
    /// `packagingApplies`.
    @State private var hasLabel = false

    /// PACKAGING IS A POSTAL CONCEPT. See `CustomerSellNextStepsCard.packagingApplies`
    /// for the full reasoning - identical here since it is the same parcel.
    private var packagingApplies: Bool {
        fulfilment == CustomerFulfilment.collection || hasLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What happens next")
                .font(.headline)

            prepStep
            fulfilmentStep
            CustomerReturnLabelStep(ticketId: ticketId, fulfilment: fulfilment, hasLabel: $hasLabel)
            if packagingApplies {
                CustomerPackagingStep(ticketId: ticketId)
            }
            arrivalStep
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Step 1: Prep

    private var prepStep: some View {
        step(icon: "checkmark.shield", title: "Turn off Stolen Device Protection") {
            Text("We run a full diagnostic that tests every feature before the repair and again once it is finished, so you can see what was working when it reached us. This feature blocks that diagnostic from completing, so please turn it off before the device comes to us: Settings, then Face ID and Passcode.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            (
                Text("Leave the passcode switched on and tell us what it is, or take it off. We have to power the device on and test it after the repair. ")
                + Text("Please do not factory reset it").fontWeight(.semibold)
                + Text(" - we are repairing it, not buying it, so a reset only loses you your data. Back up anything you would miss, take out the SIM and any memory card, and keep the case, the cable and the charger.")
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Link(destination: URL(string: "https://support.apple.com/en-gb/120340")!) {
                    Label("Apple: Stolen Device Protection", systemImage: "arrow.up.right.square")
                        .font(.footnote)
                }
                Link(destination: URL(string: "https://mendmyi.com/repairs/how-it-works")!) {
                    Label("How a repair works", systemImage: "arrow.up.right.square")
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
                Text("The day and half day you chose is a request. We will email you a two-hour window to confirm it, or offer the nearest one we can make. If it no longer suits, tell us on your order and we will rearrange it. Rearranging is free and there is no limit on how many times you can do it. We collect within 5 miles of the shop.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case CustomerFulfilment.collection:
            // The POSTAL route renders nothing here on purpose: the return-label
            // step immediately below IS the postal step - it says the same thing
            // and carries the button that does it.
            EmptyView()

        case CustomerFulfilment.visit:
            step(icon: "storefront", title: "Bring it into the shop") {
                Text("Come in during our opening hours. You do not need an appointment. Where the job allows we look at it while you wait, and if it needs longer we tell you before you leave.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        default:
            step(icon: "calendar", title: "Getting the device to us") {
                Text("We will be in touch to arrange it with you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Step 3: On arrival

    private var arrivalStep: some View {
        let isVisit = fulfilment == CustomerFulfilment.visit
        return step(
            icon: "checkmark.seal",
            title: isVisit ? "What happens at the counter" : "What happens when it reaches us"
        ) {
            Text("We run a full diagnostic before we start and again after we finish, so you can see what was working when the device reached us and what was working when it left.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(isVisit
                 ? "Then we tell you what it needs and what it costs. Say yes and we get on with it. Say no and there is nothing to pay, and you take the device home with you."
                 : "Then we send you a quote on your order. Approve it and we get on with the repair. Decline and there is nothing to pay, and we get the device back to you free of charge. We never do work you have not agreed.")
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
    CustomerRepairNextStepsCard(ticketId: "preview-ticket-id", fulfilment: "collection").padding()
}

#Preview("Doorstep") {
    CustomerRepairNextStepsCard(ticketId: "preview-ticket-id", fulfilment: "doorstep").padding()
}

#Preview("Visit") {
    CustomerRepairNextStepsCard(ticketId: "preview-ticket-id", fulfilment: "visit").padding()
}

#Preview("Unknown") {
    CustomerRepairNextStepsCard(ticketId: "preview-ticket-id", fulfilment: nil).padding()
}
