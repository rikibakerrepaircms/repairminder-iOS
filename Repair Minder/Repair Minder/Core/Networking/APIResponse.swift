//
//  APIResponse.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation

/// Standard API response wrapper matching backend format
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

/// Empty response for endpoints that return no data
struct EmptyResponse: Decodable {}

/// Pagination metadata
struct PaginationMeta: Decodable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case total, limit, offset
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decode(Int.self, forKey: .total)
        limit = try container.decode(Int.self, forKey: .limit)
        offset = try container.decode(Int.self, forKey: .offset)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
            ?? (offset + limit < total)
    }
}

/// Paginated response wrapper
struct PaginatedResponse<T: Decodable>: Decodable {
    let items: T
    let pagination: PaginationMeta
}
