//
//  DashboardStats.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

struct DashboardStats: Equatable, Sendable {
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

        struct Comparison: Equatable, Sendable {
            let period: String
            let count: Int
            let change: Int
            let changePercent: Double
        }
    }

    struct RevenueStats: Codable, Equatable, Sendable {
        let current: CurrentTotal
        let comparisons: [Comparison]

        struct CurrentTotal: Equatable, Sendable {
            let total: Double
        }

        struct Comparison: Equatable, Sendable {
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

        struct Comparison: Equatable, Sendable {
            let period: String
            let count: Int
            let change: Int
            let changePercent: Double
        }
    }
}

// MARK: - Codable
extension DashboardStats: Codable {
    enum CodingKeys: String, CodingKey {
        case period, devices, revenue, clients
        case newClients
        case returningClients
    }
}

// MARK: - DeviceStats.Comparison Codable
extension DashboardStats.DeviceStats.Comparison: Codable {
    enum CodingKeys: String, CodingKey {
        case period, count, change, changePercent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decode(String.self, forKey: .period)
        count = try container.decode(Int.self, forKey: .count)
        change = try container.decode(Int.self, forKey: .change)
        // Handle both Int and Double for changePercent
        if let intValue = try? container.decode(Int.self, forKey: .changePercent) {
            changePercent = Double(intValue)
        } else {
            changePercent = try container.decode(Double.self, forKey: .changePercent)
        }
    }
}

// MARK: - RevenueStats.CurrentTotal Codable
extension DashboardStats.RevenueStats.CurrentTotal: Codable {
    enum CodingKeys: String, CodingKey {
        case total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Handle both Int and Double for total
        if let intValue = try? container.decode(Int.self, forKey: .total) {
            total = Double(intValue)
        } else {
            total = try container.decode(Double.self, forKey: .total)
        }
    }
}

// MARK: - RevenueStats.Comparison Codable
extension DashboardStats.RevenueStats.Comparison: Codable {
    enum CodingKeys: String, CodingKey {
        case period, total, change, changePercent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decode(String.self, forKey: .period)
        // Handle both Int and Double
        if let intValue = try? container.decode(Int.self, forKey: .total) {
            total = Double(intValue)
        } else {
            total = try container.decode(Double.self, forKey: .total)
        }
        if let intValue = try? container.decode(Int.self, forKey: .change) {
            change = Double(intValue)
        } else {
            change = try container.decode(Double.self, forKey: .change)
        }
        if let intValue = try? container.decode(Int.self, forKey: .changePercent) {
            changePercent = Double(intValue)
        } else {
            changePercent = try container.decode(Double.self, forKey: .changePercent)
        }
    }
}

// MARK: - ClientStats.Comparison Codable
extension DashboardStats.ClientStats.Comparison: Codable {
    enum CodingKeys: String, CodingKey {
        case period, count, change, changePercent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decode(String.self, forKey: .period)
        count = try container.decode(Int.self, forKey: .count)
        change = try container.decode(Int.self, forKey: .change)
        // Handle both Int and Double for changePercent
        if let intValue = try? container.decode(Int.self, forKey: .changePercent) {
            changePercent = Double(intValue)
        } else {
            changePercent = try container.decode(Double.self, forKey: .changePercent)
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

    // Previous period comparisons
    var deviceChangePercent: Double? {
        devices.comparisons.first?.changePercent
    }

    var revenueChangePercent: Double? {
        revenue.comparisons.first?.changePercent
    }

    var clientChangePercent: Double? {
        clients.comparisons.first?.changePercent
    }

    var newClientChangePercent: Double? {
        newClients.comparisons.first?.changePercent
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
                    DeviceStats.Comparison(period: "Last Month", count: 38, change: 4, changePercent: 10.5)
                ]
            ),
            revenue: RevenueStats(
                current: RevenueStats.CurrentTotal(total: 8500.00),
                comparisons: [
                    RevenueStats.Comparison(period: "Last Month", total: 7200.00, change: 1300.00, changePercent: 18.0)
                ]
            ),
            clients: ClientStats(
                current: ClientStats.CurrentCount(count: 156),
                comparisons: [
                    ClientStats.Comparison(period: "Last Month", count: 148, change: 8, changePercent: 5.4)
                ]
            ),
            newClients: ClientStats(
                current: ClientStats.CurrentCount(count: 12),
                comparisons: [
                    ClientStats.Comparison(period: "Last Month", count: 10, change: 2, changePercent: 20.0)
                ]
            ),
            returningClients: ClientStats(
                current: ClientStats.CurrentCount(count: 30),
                comparisons: [
                    ClientStats.Comparison(period: "Last Month", count: 28, change: 2, changePercent: 7.1)
                ]
            )
        )
    }
}
