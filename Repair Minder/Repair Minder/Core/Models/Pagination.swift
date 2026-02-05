//
//  Pagination.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

/// Pagination metadata returned by list endpoints
struct Pagination: Decodable, Equatable, Sendable {
    /// Current page number (1-indexed)
    let page: Int

    /// Number of items per page
    let limit: Int

    /// Total number of items across all pages
    let total: Int

    /// Total number of pages
    /// Backend may return as `total_pages` (snake_case) - decoder converts automatically
    let totalPages: Int

    /// Whether there are more pages available
    var hasNextPage: Bool {
        page < totalPages
    }

    /// Whether this is the first page
    var isFirstPage: Bool {
        page == 1
    }
}
