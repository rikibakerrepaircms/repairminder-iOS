//
//  CustomerCompetitionEntry.swift
//  Repair Minder
//
//  Created on 06/07/2026.
//

import Foundation

/// A giveaway/competition entry belonging to the logged-in customer.
/// Returned from GET /api/customer/marketing/entries
struct CustomerCompetitionEntry: Codable, Identifiable, Sendable {
    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    let campaignId: String
    let campaignName: String
    let prize: String?
    let enteredAt: Date?
    let status: String
    let entryStatus: String?
    let isWinner: Bool
    let marketingOptIn: Bool

    var id: String { campaignId }

    enum CodingKeys: String, CodingKey {
        case campaignId, campaignName, prize, enteredAt, status, entryStatus, isWinner, marketingOptIn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        campaignId = try c.decode(String.self, forKey: .campaignId)
        campaignName = try c.decode(String.self, forKey: .campaignName)
        prize = try c.decodeIfPresent(String.self, forKey: .prize)
        enteredAt = MarketingDate.parse(try c.decodeIfPresent(String.self, forKey: .enteredAt))
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        entryStatus = try c.decodeIfPresent(String.self, forKey: .entryStatus)
        isWinner = (try? c.decode(Bool.self, forKey: .isWinner)) ?? ((try? c.decode(Int.self, forKey: .isWinner)) == 1)
        marketingOptIn = (try? c.decode(Bool.self, forKey: .marketingOptIn)) ?? ((try? c.decode(Int.self, forKey: .marketingOptIn)) == 1)
    }
}
