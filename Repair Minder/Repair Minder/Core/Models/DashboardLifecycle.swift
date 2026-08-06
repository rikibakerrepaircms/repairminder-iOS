//
//  DashboardLifecycle.swift
//  Repair Minder
//

import Foundation

/// Lifecycle metrics response from `/api/dashboard/lifecycle`
struct DashboardLifecycle: Decodable, Equatable, Sendable {
    let overall: LifecycleOverall
    let byEngineer: [LifecycleEngineer]?
}

/// Overall device turnaround stats for the requested scope
struct LifecycleOverall: Decodable, Equatable, Sendable {
    let avgHours: Double
    let minHours: Double
    let maxHours: Double
    let count: Int
}

/// Per-engineer turnaround stats (company scope, group_by=engineer)
struct LifecycleEngineer: Decodable, Equatable, Sendable, Identifiable {
    let userId: String
    let name: String
    let avgHours: Double
    let count: Int

    var id: String { userId }
}
