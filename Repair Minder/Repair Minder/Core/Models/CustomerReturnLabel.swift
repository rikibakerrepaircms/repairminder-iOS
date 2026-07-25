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
