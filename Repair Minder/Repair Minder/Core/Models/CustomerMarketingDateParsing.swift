//
//  CustomerMarketingDateParsing.swift
//  Repair Minder
//
//  Created on 06/07/2026.
//

import Foundation

/// Shared multi-format date parsing helper for customer marketing models
/// (`CustomerCompetitionEntry`, `CustomerMarketingPreferences`).
///
/// Mirrors the date-decode convention in `CustomerOrder.swift`: tries ISO8601
/// with fractional seconds, then ISO8601 without fractional seconds, then a
/// MySQL-style "yyyy-MM-dd HH:mm:ss" fallback (UTC).
enum MarketingDate {
    static func parse(_ str: String?) -> Date? {
        guard let str else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }

        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: str)
    }
}
