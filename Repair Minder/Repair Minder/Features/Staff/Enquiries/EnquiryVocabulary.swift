//
//  EnquiryVocabulary.swift
//  Repair Minder
//

import SwiftUI

/// What kind of thing an enquiry row is, and how the device is reaching us.
///
/// The Swift twin of `src/pages/enquiryKindBadge.ts` and
/// `src/pages/EnquiriesPage.tsx` in the repairminder repo - specifically its
/// inline `ROUTE_CHIPS` and `REPAIR_ROUTE_CHIPS` maps, which are what the web's
/// enquiry ROW renders. `deviceInboundCopy.ts` in that repo holds longer
/// sentences for the ticket-detail label panel and is a different surface; do
/// not diff against it and conclude these have drifted.
/// The wording, the three kinds and the filled-versus-outlined distinction
/// match the web dashboard deliberately, so staff read one vocabulary on both
/// and the two can be diffed rather than guessed at. Change one, change both.
///
/// NOT ticket_type. That is the staff workflow lane and is 'lead' for a plain
/// enquiry, a sell order and a repair order alike, which is exactly why the
/// row needed this.
struct EnquiryKindBadge {
    let label: String
    let color: Color

    static func `for`(_ kind: String?) -> EnquiryKindBadge? {
        switch kind {
        case "repair_order": return EnquiryKindBadge(label: "Repair order", color: .blue)
        case "sell":         return EnquiryKindBadge(label: "Sell order", color: .orange)
        case "enquiry":      return EnquiryKindBadge(label: "Enquiry", color: .secondary)
        // Old rows predate enquiry_kind - most of the table. A badge that
        // guessed would mislabel every one of them.
        default:             return nil
        }
    }
}

/// How the device gets to us. A closed set of three, and the enum values are
/// actively misleading, so never show one:
///
///   'visit'      -> they walk into the shop
///   'collection' -> POSTAL. They post it to us, on a label they print themselves
///   'doorstep'   -> we drive to them
///
/// The labels were "Walk-in" / "Postal" / "Doorstep" until 2026-08-22. "Postal"
/// said neither who posts it nor who makes the label, and the storefront's staff
/// note called the same route "Free collection" - so a sell order where the seller
/// had asked for a label was triaged as a van going out. Each label now names the
/// physical act, and they must stay that way.
///
/// The postal chip says BOTH halves - that it is postal, and that the label is ours.
/// It read "Post to us" for half a day and was taken to mean "they chose to post it
/// themselves", i.e. that nothing was owed. The list is where triage happens and a
/// tooltip does not exist on a touchscreen, so the chip carries both or neither.
///
/// WE DO NOT POST A LABEL OUT. Approving one mints it, publishes it to the
/// customer's own portal and emails them a LINK; they download and print it. The
/// thing we really do post is packaging - a jiffy bag with the label already on -
/// which is a separate request. Never blur the two.
///
/// The Swift twin of `src/components/tickets/deviceRoute.ts` on the web, which the
/// enquiries list, the ticket header and the label panel all render from. Change
/// one, change both.
struct EnquiryRouteChip {
    let label: String
    let hint: String
    let color: Color
    /// Repair is outlined, sell is filled. Without this a postal buyback and a
    /// postal repair are the same chip.
    let isOutlined: Bool

    static func `for`(kind: String?, fulfilment: String?) -> EnquiryRouteChip? {
        // Only the device-inbound kinds have a route at all.
        guard kind == "sell" || kind == "repair_order" else { return nil }
        guard let fulfilment else { return nil }

        let isRepair = kind == "repair_order"
        let who = isRepair ? "customer" : "seller"

        switch fulfilment {
        case "visit":
            return EnquiryRouteChip(
                label: "Walk-in",
                hint: "The \(who) is bringing the device into the shop. Nothing to post and no label to issue.",
                color: .purple, isOutlined: isRepair)
        case "collection":
            return EnquiryRouteChip(
                label: "Postal - our label",
                hint: "The \(who) is posting the device to us. We issue a free pre-paid Royal Mail label, which they download and print from their own portal - we do not post a label out to them.",
                color: .cyan, isOutlined: isRepair)
        case "doorstep":
            return EnquiryRouteChip(
                label: "We collect",
                hint: "We are driving out to the \(who) to collect the device. Nothing is posted either way.",
                color: .teal, isOutlined: isRepair)
        default:
            return nil
        }
    }
}
