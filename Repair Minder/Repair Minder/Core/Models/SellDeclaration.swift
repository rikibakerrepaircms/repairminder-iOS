//
//  SellDeclaration.swift
//  Repair Minder
//

import Foundation

/// What the seller told us when they placed a sell order.
///
/// The Swift twin of `src/types/sellDeclaration.ts`, decoded from `sell_declaration`
/// on both `GET /api/customer/enquiries/:ticketId` and `GET /api/tickets/:id`.
/// Built server side by `worker/src/sell_declaration.js`.
///
/// Until migration 0504 these six facts lived only in the free text of the staff
/// note, and the customer portal filters notes out entirely - so a seller could never
/// be shown their own answers. Sell order 100002861 ticked "Brand new - factory
/// sealed, never activated, no iCloud / Google Account lock" and, in the same
/// submission, wrote that they had forgotten the pattern and needed the device
/// factory reset. Those cannot both be true, and the one person able to spot it was
/// the only person never shown the two together.
///
/// NIL - not an empty value - on every kind but 'sell' and on every ticket predating
/// the columns, which is most of them. Every surface renders NOTHING in that case
/// rather than a card of dashes.
struct SellDeclaration: Codable, Equatable, Sendable {
    /// The grade they picked, verbatim as the storefront labelled it.
    let condition: String?
    /// The figure we showed them, already formatted ("£57.00"). Never arithmetic -
    /// it is a record of what they were told, not a price to compute with.
    let quotedPrice: String?
    let priceLockDays: Int?
    /// Three states, never two: true confirmed, false explicitly not, nil never
    /// asked. Collapsing nil to false would accuse every historic seller of
    /// refusing a question they were never shown.
    let ownershipConfirmed: Bool?
    /// Condition criteria they ticked, in the storefront's own wording.
    let confirmed: [String]
    /// Criteria they left unticked. For staff this is the bench checklist.
    let notConfirmed: [String]

    enum CodingKeys: String, CodingKey {
        case condition, quotedPrice, priceLockDays, ownershipConfirmed, confirmed, notConfirmed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        condition = try c.decodeIfPresent(String.self, forKey: .condition)
        quotedPrice = try c.decodeIfPresent(String.self, forKey: .quotedPrice)
        priceLockDays = try c.decodeIfPresent(Int.self, forKey: .priceLockDays)
        ownershipConfirmed = try c.decodeIfPresent(Bool.self, forKey: .ownershipConfirmed)
        // Absent and null both mean "no list", never a decode failure that would take
        // the whole enquiry down with it.
        confirmed = try c.decodeIfPresent([String].self, forKey: .confirmed) ?? []
        notConfirmed = try c.decodeIfPresent([String].self, forKey: .notConfirmed) ?? []
    }

    /// Memberwise init for previews and tests, since the custom decoder replaces the
    /// synthesised one.
    init(
        condition: String? = nil,
        quotedPrice: String? = nil,
        priceLockDays: Int? = nil,
        ownershipConfirmed: Bool? = nil,
        confirmed: [String] = [],
        notConfirmed: [String] = []
    ) {
        self.condition = condition
        self.quotedPrice = quotedPrice
        self.priceLockDays = priceLockDays
        self.ownershipConfirmed = ownershipConfirmed
        self.confirmed = confirmed
        self.notConfirmed = notConfirmed
    }

    /// The ownership gate spelled out.
    ///
    /// The storefront asks it as one hard gate and stores a single boolean, so the
    /// full sentence lives in the clients rather than the database. A seller shown a
    /// bare tick against the word "Ownership" has not been reminded of anything - the
    /// point is that they read the clauses again. Word for word with
    /// SellDeclarationCard.tsx.
    static let ownershipStatement =
        "You own it outright - not on contract or finance, not part of an insurance claim, and not reported lost or stolen."
}
