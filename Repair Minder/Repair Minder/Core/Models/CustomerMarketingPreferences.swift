//
//  CustomerMarketingPreferences.swift
//  Repair Minder
//
//  Created on 06/07/2026.
//

import Foundation

/// The logged-in customer's marketing consent preferences.
/// Returned from / updated via GET|PUT /api/customer/marketing/preferences
struct CustomerMarketingPreferences: Codable, Sendable {
    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    let marketingConsent: Bool
    let marketingConsentAt: Date?
    let marketingConsentSource: String?
    let marketingConsentWithdrawnAt: Date?

    enum CodingKeys: String, CodingKey {
        case marketingConsent, marketingConsentAt, marketingConsentSource, marketingConsentWithdrawnAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        marketingConsent = (try? c.decode(Bool.self, forKey: .marketingConsent)) ?? ((try? c.decode(Int.self, forKey: .marketingConsent)) == 1)
        marketingConsentAt = MarketingDate.parse(try c.decodeIfPresent(String.self, forKey: .marketingConsentAt))
        marketingConsentSource = try c.decodeIfPresent(String.self, forKey: .marketingConsentSource)
        marketingConsentWithdrawnAt = MarketingDate.parse(try c.decodeIfPresent(String.self, forKey: .marketingConsentWithdrawnAt))
    }
}
