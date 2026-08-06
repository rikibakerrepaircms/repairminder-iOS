//
//  DashboardCategoryDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct DashboardCategoryDecodeTests {
    @Test func decodes() throws {
        let json = #"""
        {"categories":[{"type":"repair","count":4,"total":400,"avg":100,"percent":80}],
         "total_revenue":500,"total_count":5}
        """#
        let c = try RMDecode.decode(DashboardCategoryBreakdown.self, json)
        #expect(c.categories.first?.type == "repair")
        #expect(c.totalRevenue == 500)
        #expect(c.totalCount == 5)
    }

    @Test func decodesEmptyCategories() throws {
        let json = #"""
        {"categories":[],"total_revenue":0,"total_count":0}
        """#
        let c = try RMDecode.decode(DashboardCategoryBreakdown.self, json)
        #expect(c.categories.isEmpty)
    }
}
