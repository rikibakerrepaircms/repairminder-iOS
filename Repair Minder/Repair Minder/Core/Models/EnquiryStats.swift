//
//  EnquiryStats.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Enquiry Stats Response

/// Enquiry statistics response from `/api/dashboard/enquiry-stats`
struct EnquiryStats: Decodable, Equatable, Sendable {
    let leads: PeriodMetrics
    let firstReplies: PeriodMetrics
    let allReplies: PeriodMetrics
    let internalNotes: PeriodMetrics

    /// Company average response time in minutes
    let companyAvgResponseMinutes: Double?

    /// User average response time in minutes (only for user scope)
    let userAvgResponseMinutes: Double?

    /// User breakdown (only for company scope with include_breakdown=true)
    let byUser: [UserEnquiryBreakdown]?
}

// MARK: - Period Metrics

/// Metrics across time periods (today, yesterday, this_week, this_month)
struct PeriodMetrics: Decodable, Equatable, Sendable {
    let today: PeriodValue
    let yesterday: PeriodValue
    let thisWeek: PeriodValue
    let thisMonth: PeriodValue

    /// Get value for a specific period
    subscript(period: StatPeriod) -> PeriodValue {
        switch period {
        case .today: return today
        case .yesterday: return yesterday
        case .thisWeek: return thisWeek
        case .thisMonth: return thisMonth
        }
    }
}

/// Single period value with change tracking
struct PeriodValue: Decodable, Equatable, Sendable {
    let count: Int
    let change: Int?
    let changePercent: Double?

    /// Change direction for display
    var changeDirection: ChangeDirection {
        guard let change = change else { return .neutral }
        if change > 0 { return .up }
        if change < 0 { return .down }
        return .neutral
    }
}

// MARK: - Time Periods

/// Available statistic time periods
enum StatPeriod: String, CaseIterable, Identifiable, Sendable {
    case today
    case yesterday
    case thisWeek = "this_week"
    case thisMonth = "this_month"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        }
    }

    var shortName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yest."
        case .thisWeek: return "Week"
        case .thisMonth: return "Month"
        }
    }
}

// MARK: - User Breakdown

/// Per-user enquiry statistics breakdown
struct UserEnquiryBreakdown: Decodable, Equatable, Sendable, Identifiable {
    let userId: String
    let name: String
    let firstReplies: Int
    let allReplies: Int
    let notes: Int
    let avgResponseMinutes: Double?

    var id: String { userId }

    /// Formatted average response time
    var formattedAvgResponseTime: String {
        guard let minutes = avgResponseMinutes else { return "-" }
        if minutes < 60 {
            return String(format: "%.0f min", minutes)
        }
        let hours = minutes / 60
        if hours < 24 {
            return String(format: "%.1f hrs", hours)
        }
        let days = hours / 24
        return String(format: "%.1f days", days)
    }
}

// MARK: - Dashboard Scope

/// Dashboard data scope
enum DashboardScope: String, CaseIterable, Identifiable, Sendable {
    case user
    case company

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .user: return "My Stats"
        case .company: return "Company"
        }
    }
}
