//
//  CustomerEnquiry.swift
//  Repair Minder
//
//  Created on 25/07/2026.
//

import Foundation

// MARK: - Enquiry Kind

/// What a ticket actually is, as persisted by the storefront enquiry endpoint
/// (`worker/src/storefront_enquiry_kind.js`). Null on every ticket created before
/// migration 0383, and null must read as an ordinary enquiry.
///
/// This is NOT `ticket_type`. `ticket_type` is the staff workflow lane
/// ('lead' | 'order' | 'support') and stays 'lead' for a sell order so it keeps
/// its place in the staff Enquiries list and its Convert to Order button.
enum CustomerEnquiryKind {
    static let sell = "sell"
    static let repairOrder = "repair_order"
    static let enquiry = "enquiry"
}

/// How the customer asked to get the device to us. Null when they never chose,
/// which is every enquiry that is not a sell order.
///
/// Mirrors `KNOWN_FULFILMENTS` in `worker/src/storefront_enquiry_kind.js`.
/// `doorstep` is a distinct route, not a flavour of `collection`: `collection`
/// is the POSTAL route where we send a pre-paid label, and `doorstep` is the one
/// where we come to their door and there is a slot to agree. The two were a
/// single value until 2026-07-25, so any code that reads `collection` and talks
/// about a slot, a van or a two-hour window is a leftover from that conflation.
enum CustomerFulfilment {
    static let visit = "visit"
    static let collection = "collection"
    static let doorstep = "doorstep"
}

// MARK: - Enquiry Summary

/// Row in `GET /api/customer/enquiries`.
struct CustomerEnquirySummary: Decodable, Identifiable, Sendable {
    let id: String
    let ticketNumber: Int
    let subject: String?
    let status: String
    let ticketType: String?
    let enquiryKind: String?
    let fulfilment: String?
    let createdAt: Date?

    // Decoded with .convertFromSnakeCase, so no raw CodingKeys values here.
    enum CodingKeys: String, CodingKey {
        case id, ticketNumber, subject, status, ticketType, enquiryKind, fulfilment, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        ticketNumber = try c.decode(Int.self, forKey: .ticketNumber)
        subject = try c.decodeIfPresent(String.self, forKey: .subject)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "open"
        ticketType = try c.decodeIfPresent(String.self, forKey: .ticketType)
        enquiryKind = try c.decodeIfPresent(String.self, forKey: .enquiryKind)
        fulfilment = try c.decodeIfPresent(String.self, forKey: .fulfilment)
        // D1 hands back "yyyy-MM-dd HH:mm:ss" here rather than ISO8601. Shared
        // parser, same convention as CustomerOrder and the marketing models.
        createdAt = MarketingDate.parse(try c.decodeIfPresent(String.self, forKey: .createdAt))
    }

    /// Whether this enquiry is a device we have agreed to buy.
    var isSell: Bool { enquiryKind == CustomerEnquiryKind.sell }

    /// Whether this is a repair we have agreed to do.
    var isRepairOrder: Bool { enquiryKind == CustomerEnquiryKind.repairOrder }

    /// Whether a device is on its way to us, so a label, packaging and a
    /// collection slot all apply. The Swift twin of `expectsDevice` in
    /// worker/src/storefront_enquiry_kind.js - change one, change both.
    var expectsDevice: Bool { isSell || isRepairOrder }

    var displaySubject: String {
        let trimmed = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Enquiry #\(ticketNumber)" : trimmed
    }
}

// MARK: - Enquiry Detail

/// Response body of `GET /api/customer/enquiries/:ticketId`.
///
/// Note the endpoint does NOT return the ticket id, only its number, so there is
/// no `id` here. Callers already hold the id they asked for.
struct CustomerEnquiryDetail: Decodable, Sendable {
    let ticketNumber: Int
    let subject: String?
    let status: String
    let ticketType: String?
    let enquiryKind: String?
    let fulfilment: String?
    /// True for a sell lead with no catalog price and no staff review yet (the
    /// storefront's "not listed" / custom-quote flow). Gates
    /// CustomerSellNextStepsCard off in favour of CustomerUnlistedItemLeadCard.
    let isUnlistedItem: Bool
    let createdAt: Date?
    let messages: [CustomerMessage]
    let company: CustomerEnquiryCompany?
    /// Nil on every enquiry with no doorstep collection in play, which is most.
    let collectionSlot: CollectionSlot?
    /// What the seller told us at order time - grade, quoted figure, price hold and
    /// the ownership/condition attestations. Nil on every kind but 'sell' and on
    /// every ticket predating migration 0504; the card renders nothing then.
    let sellDeclaration: SellDeclaration?

    enum CodingKeys: String, CodingKey {
        case ticketNumber, subject, status, ticketType, enquiryKind, fulfilment, isUnlistedItem, createdAt, messages, company
        case collectionSlot
        case sellDeclaration
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ticketNumber = try c.decode(Int.self, forKey: .ticketNumber)
        subject = try c.decodeIfPresent(String.self, forKey: .subject)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "open"
        ticketType = try c.decodeIfPresent(String.self, forKey: .ticketType)
        enquiryKind = try c.decodeIfPresent(String.self, forKey: .enquiryKind)
        fulfilment = try c.decodeIfPresent(String.self, forKey: .fulfilment)
        // decodeIfPresent ?? false: every ticket predating this field, and every
        // response from a not-yet-updated backend, reads as "not an unlisted
        // lead" - the same fail-safe default the column itself uses.
        isUnlistedItem = try c.decodeIfPresent(Bool.self, forKey: .isUnlistedItem) ?? false
        createdAt = MarketingDate.parse(try c.decodeIfPresent(String.self, forKey: .createdAt))
        messages = try c.decodeIfPresent([CustomerMessage].self, forKey: .messages) ?? []
        company = try c.decodeIfPresent(CustomerEnquiryCompany.self, forKey: .company)
        collectionSlot = try c.decodeIfPresent(CollectionSlot.self, forKey: .collectionSlot)
        sellDeclaration = try c.decodeIfPresent(SellDeclaration.self, forKey: .sellDeclaration)
    }

    var isSell: Bool { enquiryKind == CustomerEnquiryKind.sell }

    /// Whether this is a repair we have agreed to do.
    var isRepairOrder: Bool { enquiryKind == CustomerEnquiryKind.repairOrder }

    /// Whether a device is on its way to us, so a label, packaging and a
    /// collection slot all apply. The Swift twin of `expectsDevice` in
    /// worker/src/storefront_enquiry_kind.js - change one, change both.
    var expectsDevice: Bool { isSell || isRepairOrder }

    /// The device has been booked in. `handleCreateOrder` flips ticket_type to
    /// 'order' at conversion, so this needs no new field. Once true, the
    /// next-steps card stands down: it would otherwise keep offering a postage
    /// label for a parcel that has already reached us.
    var deviceIsWithUs: Bool { ticketType == "order" }

    /// Whether this is an ORDER, and so has an order ID to quote, rather than an
    /// ordinary enquiry - someone who asked us a question has no order. Keyed on
    /// enquiryKind, never ticketType: that is the staff workflow lane and stays
    /// 'lead' even on a sell order.
    var isOrder: Bool {
        enquiryKind == CustomerEnquiryKind.sell || enquiryKind == CustomerEnquiryKind.repairOrder
    }

    var displaySubject: String {
        let trimmed = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Enquiry #\(ticketNumber)" : trimmed
    }
}

/// The company branding block the enquiry endpoint returns. Only the name is used
/// today; logo URLs are decoded so a future change does not need a model edit.
struct CustomerEnquiryCompany: Decodable, Sendable {
    let name: String?
    let logoUrl: String?
    let faviconUrl: String?
    /// The shop, or every shop when the ticket is assigned to none. Ordered by
    /// `is_primary DESC` server side, so the first entry is the one to show.
    /// Additive: this has always been in the response, it simply was not decoded.
    let locations: [CustomerEnquiryLocation]?
}

/// A shop as `GET /api/customer/enquiries/:ticketId` returns it.
///
/// Everything is Optional because everything genuinely can be null in D1, and each
/// field drops its own element rather than rendering a placeholder. `googleMapsUrl`
/// is built server side from `google_place_id`; `appleMapsUrl` is the column
/// verbatim. Twin of `SellStepsLocation` in `SellNextStepsCard.tsx`.
struct CustomerEnquiryLocation: Decodable, Sendable {
    let name: String?
    let phone: String?
    let email: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let postcode: String?
    let openingHours: [String: CustomerEnquiryDayHours?]?
    let googleMapsUrl: String?
    let appleMapsUrl: String?

    /// "3 Queen Street, Haverhill, CB9 9DZ", with absent parts simply left out.
    var oneLineAddress: String {
        [addressLine1, addressLine2, city, postcode]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// One day's hours. A day that is absent, or null, is a day we are closed.
struct CustomerEnquiryDayHours: Decodable, Sendable {
    let open: String
    let close: String
}

// MARK: - Status Display

/// Status pill wording, matching the customer portal's statusLabels map in
/// CustomerEnquiryDetailPage.tsx so the app and the web say the same words.
enum CustomerEnquiryStatus {
    static func label(for status: String) -> String {
        switch status {
        case "open": return "Open"
        case "pending": return "Pending"
        case "resolved": return "Resolved"
        case "closed": return "Closed"
        default: return "Open"
        }
    }

    /// A closed or resolved enquiry hides the reply box, as on the web.
    static func isClosed(_ status: String) -> Bool {
        status == "closed" || status == "resolved"
    }
}
