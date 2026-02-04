//
//  DashboardStats.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

struct DashboardStats: Codable, Equatable, Sendable {
    let period: String
    let devices: DeviceStats
    let revenue: RevenueStats
    let clients: ClientStats
    let newClients: ClientStats
    let returningClients: ClientStats

    struct DeviceStats: Codable, Equatable, Sendable {
        let current: CurrentCount
        let comparisons: [Comparison]

        struct CurrentCount: Codable, Equatable, Sendable {
            let count: Int
        }

        struct Comparison: Codable, Equatable, Sendable {
            let period: String
            let count: Int
            let change: Int
            let changePercent: Double
        }
    }

    struct RevenueStats: Codable, Equatable, Sendable {
        let current: CurrentTotal
        let comparisons: [Comparison]

        struct CurrentTotal: Codable, Equatable, Sendable {
            let total: Double
        }

        struct Comparison: Codable, Equatable, Sendable {
            let period: String
            let total: Double
            let change: Double
            let changePercent: Double
        }
    }

    struct ClientStats: Codable, Equatable, Sendable {
        let current: CurrentCount
        let comparisons: [Comparison]

        struct CurrentCount: Codable, Equatable, Sendable {
            let count: Int
        }

        struct Comparison: Codable, Equatable, Sendable {
            let period: String
            let count: Int
            let change: Int
            let changePercent: Double
        }
    }
}

// MARK: - Convenience Properties
extension DashboardStats {
    var currentDeviceCount: Int {
        devices.current.count
    }

    var currentRevenue: Double {
        revenue.current.total
    }

    var currentClientCount: Int {
        clients.current.count
    }

    var currentNewClientCount: Int {
        newClients.current.count
    }

    var currentReturningClientCount: Int {
        returningClients.current.count
    }

    // Previous period comparisons (typically last month)
    var deviceChangeFromLastMonth: Int? {
        devices.comparisons.first(where: { $0.period == "last_month" })?.change
    }

    var revenueChangeFromLastMonth: Double? {
        revenue.comparisons.first(where: { $0.period == "last_month" })?.change
    }

    var deviceChangePercentFromLastMonth: Double? {
        devices.comparisons.first(where: { $0.period == "last_month" })?.changePercent
    }

    var revenueChangePercentFromLastMonth: Double? {
        revenue.comparisons.first(where: { $0.period == "last_month" })?.changePercent
    }
}

// MARK: - Sample Data for Previews
extension DashboardStats {
    static var sample: DashboardStats {
        DashboardStats(
            period: "this_month",
            devices: DeviceStats(
                current: DeviceStats.CurrentCount(count: 42),
                comparisons: [
                    DeviceStats.Comparison(period: "last_month", count: 38, change: 4, changePercent: 10.5),
                    DeviceStats.Comparison(period: "same_month_last_year", count: 35, change: 7, changePercent: 20.0)
                ]
            ),
            revenue: RevenueStats(
                current: RevenueStats.CurrentTotal(total: 8500.00),
                comparisons: [
                    RevenueStats.Comparison(period: "last_month", total: 7200.00, change: 1300.00, changePercent: 18.0),
                    RevenueStats.Comparison(period: "same_month_last_year", total: 6800.00, change: 1700.00, changePercent: 25.0)
                ]
            ),
            clients: ClientStats(
                current: ClientStats.CurrentCount(count: 156),
                comparisons: [
                    ClientStats.Comparison(period: "last_month", count: 148, change: 8, changePercent: 5.4)
                ]
            ),
            newClients: ClientStats(
                current: ClientStats.CurrentCount(count: 12),
                comparisons: [
                    ClientStats.Comparison(period: "last_month", count: 10, change: 2, changePercent: 20.0)
                ]
            ),
            returningClients: ClientStats(
                current: ClientStats.CurrentCount(count: 30),
                comparisons: [
                    ClientStats.Comparison(period: "last_month", count: 28, change: 2, changePercent: 7.1)
                ]
            )
        )
    }
}
