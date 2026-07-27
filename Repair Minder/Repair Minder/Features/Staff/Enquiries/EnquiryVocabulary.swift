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

/// How the device gets to us. A closed set of three: 'visit' (they come in),
/// 'collection' (POSTAL, we send a label) and 'doorstep' (we drive to them).
///
/// "We collect" means OUR van, within the local radius, with a slot to agree.
/// The postal route also ends with someone at the door, but that is Royal
/// Mail's collection, booked by the customer with the tracking number. The
/// labels here keep them apart and must not be blurred.
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
                hint: "The \(who) is bringing the device into the shop",
                color: .purple, isOutlined: isRepair)
        case "collection":
            return EnquiryRouteChip(
                label: "Postal",
                hint: "The \(who) asked us to send a pre-paid postage label",
                color: .cyan, isOutlined: isRepair)
        case "doorstep":
            return EnquiryRouteChip(
                label: "Doorstep",
                hint: "We are collecting the device from the \(who)",
                color: .teal, isOutlined: isRepair)
        default:
            return nil
        }
    }
}
