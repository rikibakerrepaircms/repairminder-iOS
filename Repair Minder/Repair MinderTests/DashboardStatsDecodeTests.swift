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

    @Test func testDecodesCompanyScopePayload() throws {
        let json = #"""
        {
          "period":"this_month",
          "devices":{"current":{"count":3},"comparisons":[]},
          "revenue":{"current":{"total":1000},"comparisons":[]},
          "clients":{"current":{"count":5},"comparisons":[]},
          "new_clients":{"current":{"count":2},"comparisons":[]},
          "returning_clients":{"current":{"count":3},"comparisons":[]},
          "refunds":{"current":{"total":50,"count":1},"comparisons":[]},
          "company_comparison":{"user_avg_lifecycle_hours":null,"company_avg_lifecycle_hours":4.2},
          "awaiting_collection":{"outstanding_balance":120,"order_count":2,"device_count":2,"avg_wait_hours":6.5},
          "unpaid_collected":{"total":80,"count":1,"order_ids":["o1"]},
          "payment_mismatch":{"count":1,"order_ids":["o2"],"total_discrepancy":5},
          "revenue_breakdown":{"repair":600,"accessories":50,"device_sale":200,"buyback_sales":150,"buyback_purchases":100,"other":0,"total":1000},
          "avg_order_value":{"current":{"total":250},"comparisons":[]},
          "repeat_rate":{"current":40}
        }
        """#
        let stats = try RMDecode.decode(DashboardStats.self, json)
        #expect(stats.awaitingCollection?.deviceCount == 2)
        #expect(stats.unpaidCollected?.total == 80)
        #expect(stats.paymentMismatch?.totalDiscrepancy == 5)
        #expect(stats.revenueBreakdown?.buybackSales == 150)
        #expect(stats.avgOrderValue?.current.total == 250)
        #expect(stats.repeatRate?.current == 40)
    }
}
