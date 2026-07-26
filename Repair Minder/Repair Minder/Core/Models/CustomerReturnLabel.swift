//
//  CustomerReturnLabel.swift
//  Repair Minder
//
//  Created on 25/07/2026.
//

import Foundation

/// Return-label state for a buyback sell enquiry.
///
/// Backs `GET /api/customer/enquiries/:ticketId/return-label` and the object
/// `POST` to the same path returns. Field names match the API exactly; the
/// decoder uses `.convertFromSnakeCase`, so a rename on either side is a
/// silent decode failure on iPhone, iPad AND Mac at once - they share this
/// model.
///
/// `created_at`/`expires_at` come back from D1 as "yyyy-MM-dd HH:mm:ss" (UTC,
/// no timezone marker), not ISO8601 - `MarketingDate.parse` tries ISO8601
/// first and falls back to that MySQL-style form, the same convention as
/// every other customer-portal model (`CustomerEnquiry`, `CustomerOrder`).
/// Using plain `ISO8601DateFormatter`/`Date(from:)` here would silently
/// decode both fields as nil.
struct CustomerReturnLabel: Decodable, Equatable, Sendable {
    let trackingNumber: String
    let serviceCode: String
    let createdAt: Date?
    let expiresAt: Date?
    let pdfUrl: String

    enum CodingKeys: String, CodingKey {
        case trackingNumber, serviceCode, createdAt, expiresAt, pdfUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trackingNumber = try c.decode(String.self, forKey: .trackingNumber)
        serviceCode = try c.decode(String.self, forKey: .serviceCode)
        createdAt = MarketingDate.parse(try c.decodeIfPresent(String.self, forKey: .createdAt))
        expiresAt = MarketingDate.parse(try c.decodeIfPresent(String.self, forKey: .expiresAt))
        pdfUrl = try c.decode(String.self, forKey: .pdfUrl)
    }

    /// Days remaining of the label's 14-day life, computed from `expiresAt`.
    /// Nil when `expiresAt` itself is nil - never invent a number the API did
    /// not send.
    var daysRemaining: Int? {
        guard let expiresAt else { return nil }
        return Int(ceil(expiresAt.timeIntervalSinceNow / (60 * 60 * 24)))
    }

    /// True once `daysRemaining` has reached zero or gone negative. False
    /// (not true) when `expiresAt` is missing, matching the web card, which
    /// only shows the "expired" state when it can prove it from a real date.
    var isExpired: Bool {
        guard let daysRemaining else { return false }
        return daysRemaining <= 0
    }
}

/// An address supplied on the return-label create, for the one client this
/// endpoint can be missing one entirely: a repair walk-in, who is deliberately
/// never asked for an address on the storefront (a repair only needs one
/// where we are actually collecting, unlike a buyback, which always records
/// the seller's - see `CustomerReturnLabelViewModel.requestLabel`).
///
/// Encoded, not decoded, so this uses explicit `CodingKeys` rather than
/// `.convertFromSnakeCase` (that strategy only applies to the decoder the
/// rest of this file's models share). `addressLine1`/`postcode` are what the
/// server actually needs to address a parcel; `addressLine2`/`city` are
/// optional on the wire, same as the web card's form.
struct CustomerReturnLabelAddress: Encodable, Equatable, Sendable {
    var addressLine1: String = ""
    var addressLine2: String = ""
    var city: String = ""
    var postcode: String = ""

    enum CodingKeys: String, CodingKey {
        case addressLine1 = "address_line_1"
        case addressLine2 = "address_line_2"
        case city
        case postcode
    }
}

/// Whether the seller has asked us to post them packaging, and when.
///
/// Backs `GET|POST /api/customer/enquiries/:ticketId/packaging-request`. This is
/// a REQUEST and not a label: the outbound leg is Royal Mail Tracked 24, billed
/// at manifest whether the parcel ships or not, so a customer press records this
/// timestamp and a human decides whether to send anything.
///
/// `packaging_requested_at` comes from D1 as "yyyy-MM-dd HH:mm:ss" (UTC, no
/// timezone marker), so it goes through `MarketingDate.parse` for the same
/// reason `createdAt`/`expiresAt` above do - a plain ISO8601 decoder yields nil.
struct PackagingRequest: Decodable, Equatable, Sendable {
    /// The parsed timestamp, for anywhere a date is actually displayed. Nil both
    /// when the seller never asked AND when the string could not be parsed - so
    /// this must not be what the view branches on. Use `hasAsked`.
    let packagingRequestedAt: Date?

    /// Whether the API sent a timestamp at all, independent of whether it parsed.
    /// This is what the view branches on: a date format we failed to read must
    /// still count as "asked", or we would re-offer a button the seller has
    /// already pressed and invite a duplicate request.
    let hasAsked: Bool

    enum CodingKeys: String, CodingKey {
        case packagingRequestedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decodeIfPresent(String.self, forKey: .packagingRequestedAt)
        hasAsked = raw != nil
        packagingRequestedAt = MarketingDate.parse(raw)
    }

    /// Memberwise init for previews and tests, which have no JSON to decode.
    init(packagingRequestedAt: Date?) {
        self.packagingRequestedAt = packagingRequestedAt
        self.hasAsked = packagingRequestedAt != nil
    }
}
