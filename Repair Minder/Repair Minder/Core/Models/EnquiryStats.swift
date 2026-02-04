//
//  EnquiryStats.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

struct EnquiryStats: Codable, Equatable, Sendable {
    let newToday: Int
    let awaitingReply: Int
    let convertedThisWeek: Int
    let totalActive: Int

    enum CodingKeys: String, CodingKey {
        case newToday
        case awaitingReply
        case convertedThisWeek
        case totalActive
    }

    init(newToday: Int = 0, awaitingReply: Int = 0, convertedThisWeek: Int = 0, totalActive: Int = 0) {
        self.newToday = newToday
        self.awaitingReply = awaitingReply
        self.convertedThisWeek = convertedThisWeek
        self.totalActive = totalActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        newToday = try container.decodeIfPresent(Int.self, forKey: .newToday) ?? 0
        awaitingReply = try container.decodeIfPresent(Int.self, forKey: .awaitingReply) ?? 0
        convertedThisWeek = try container.decodeIfPresent(Int.self, forKey: .convertedThisWeek) ?? 0
        totalActive = try container.decodeIfPresent(Int.self, forKey: .totalActive) ?? 0
    }

    static let empty = EnquiryStats()
}
