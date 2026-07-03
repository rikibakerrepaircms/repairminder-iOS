//
//  DashboardHeatmap.swift
//  Repair Minder
//

import Foundation

/// Booking heatmap response from `/api/dashboard/booking-heatmap`
struct DashboardHeatmap: Decodable, Equatable, Sendable {
    let heatmap: [HeatmapCell]
    let maxCount: Int
}

/// A single day-of-week / hour-of-day booking count bucket (company-local time)
struct HeatmapCell: Decodable, Equatable, Sendable, Identifiable {
    let day: Int
    let hour: Int
    let count: Int

    var id: String { "\(day)-\(hour)" }
}
