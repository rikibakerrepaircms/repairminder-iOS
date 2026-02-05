//
//  DashboardStats.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Dashboard Stats Response

/// Dashboard statistics response from `/api/dashboard/stats`
struct DashboardStats: Decodable, Equatable, Sendable {
    let period: String
    let devices: StatMetric<CountCurrent>
    let revenue: StatMetric<RevenueCurrent>
    let clients: StatMetric<CountCurrent>
    let newClients: StatMetric<CountCurrent>
    let returningClients: StatMetric<CountCurrent>
    let refunds: StatMetric<RefundCurrent>

    /// Dual attribution data - only present for user scope
    let attribution: Attribution?

    /// Lifecycle comparison - user vs company average
    let companyComparison: LifecycleComparison?

    /// Company-only metrics (when scope=company)
    let awaitingCollection: AwaitingCollectionMetrics?
    let unpaidCollected: UnpaidCollectedMetrics?
    let paymentMismatch: PaymentMismatchMetrics?
    let revenueBreakdown: RevenueCategoryBreakdown?
}

// MARK: - Generic Metric Types

/// Generic stat metric with current value and comparisons
struct StatMetric<T: Decodable & Equatable & Sendable>: Decodable, Equatable, Sendable {
    let current: T
    let comparisons: [StatComparison]
}

/// Count-based current value
struct CountCurrent: Decodable, Equatable, Sendable {
    let count: Int
}

/// Revenue-based current value
struct RevenueCurrent: Decodable, Equatable, Sendable {
    let total: Double
}

/// Refund current value with both total and count
struct RefundCurrent: Decodable, Equatable, Sendable {
    let total: Double
    let count: Int
}

/// Comparison period data
struct StatComparison: Decodable, Equatable, Sendable, Identifiable {
    let period: String
    let count: Int?
    let total: Double?
    let change: Double
    let changePercent: Double

    var id: String { period }

    /// Display value - count or total depending on metric type
    var displayValue: String {
        if let count = count {
            return "\(count)"
        }
        if let total = total {
            return String(format: "%.2f", total)
        }
        return "-"
    }

    /// Change indicator direction
    var changeDirection: ChangeDirection {
        if change > 0 {
            return .up
        } else if change < 0 {
            return .down
        }
        return .neutral
    }
}

/// Direction of change for display
enum ChangeDirection {
    case up, down, neutral
}

// MARK: - Attribution

/// Dual attribution data for user scope
struct Attribution: Decodable, Equatable, Sendable {
    let bookedIn: AttributionData
    let repaired: AttributionData
}

/// Individual attribution bucket
struct AttributionData: Decodable, Equatable, Sendable {
    let count: Int
    let revenue: Double
}

// MARK: - Lifecycle Comparison

/// User vs company lifecycle comparison
struct LifecycleComparison: Decodable, Equatable, Sendable {
    let userAvgLifecycleHours: Double?
    let companyAvgLifecycleHours: Double?

    /// User's performance relative to company
    var performanceIndicator: String {
        guard let user = userAvgLifecycleHours, let company = companyAvgLifecycleHours else {
            return "-"
        }
        if user < company {
            let diff = company - user
            return String(format: "%.1f hrs faster", diff)
        } else if user > company {
            let diff = user - company
            return String(format: "%.1f hrs slower", diff)
        }
        return "Same as average"
    }
}

// MARK: - Company-Only Metrics

/// Awaiting collection metrics
struct AwaitingCollectionMetrics: Decodable, Equatable, Sendable {
    let outstandingBalance: Double
    let orderCount: Int
    let deviceCount: Int
    let avgWaitHours: Double
}

/// Unpaid collected orders metrics
struct UnpaidCollectedMetrics: Decodable, Equatable, Sendable {
    let total: Double
    let count: Int
    let orderIds: [String]
}

/// Payment mismatch metrics
struct PaymentMismatchMetrics: Decodable, Equatable, Sendable {
    let count: Int
    let orderIds: [String]
    let totalDiscrepancy: Double
}

/// Revenue breakdown by category
struct RevenueCategoryBreakdown: Decodable, Equatable, Sendable {
    let repair: Double?
    let accessories: Double?
    let deviceSale: Double?
    let buybackSales: Double?
    let buybackPurchases: Double?
    let other: Double?
    let total: Double
}
