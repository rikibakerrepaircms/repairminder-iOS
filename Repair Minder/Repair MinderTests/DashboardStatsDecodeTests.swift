//
//  DashboardStatsDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct DashboardStatsDecodeTests {
    @Test func dashboardStatsDecodes() throws {
        let json = #"""
        {"period":"this_month","devices":{"current":{"count":0},"comparisons":[{"period":"Last Month","count":0,"change":0,"change_percent":0}]},"revenue":{"current":{"total":0},"comparisons":[{"period":"Last Month","total":0,"change":0,"change_percent":0}]},"clients":{"current":{"count":0},"comparisons":[{"period":"Last Month","count":1,"change":-1,"change_percent":-100}]},"new_clients":{"current":{"count":0},"comparisons":[{"period":"Last Month","count":0,"change":0,"change_percent":0}]},"returning_clients":{"current":{"count":0},"comparisons":[{"period":"Last Month","count":1,"change":-1,"change_percent":-100}]},"refunds":{"current":{"total":0,"count":0},"comparisons":[{"period":"Last Month","total":0,"count":0,"change":0,"change_percent":0}]},"attribution":{"booked_in":{"count":0,"revenue":0},"repaired":{"count":0,"revenue":0}},"company_comparison":{"user_avg_lifecycle_hours":null,"company_avg_lifecycle_hours":null}}
        """#
        let stats = try RMDecode.decode(DashboardStats.self, json)
        #expect(stats.revenue.current.total >= 0)
    }
}
