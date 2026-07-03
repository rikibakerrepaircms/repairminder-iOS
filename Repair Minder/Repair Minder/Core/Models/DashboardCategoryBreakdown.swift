//
//  DashboardCategoryBreakdown.swift
//  Repair Minder
//

import Foundation

/// Category breakdown response from `/api/dashboard/category-breakdown`
struct DashboardCategoryBreakdown: Decodable, Equatable, Sendable {
    let categories: [CategoryBreakdownItem]
    let totalRevenue: Double
    let totalCount: Int
}

/// Revenue/count for a single item type (repair, accessories, device_sale, ...)
struct CategoryBreakdownItem: Decodable, Equatable, Sendable, Identifiable {
    let type: String
    let count: Int
    let total: Double
    let avg: Double?
    let percent: Double?

    var id: String { type }
}
