//
//  DashboardLifecycleDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct DashboardLifecycleDecodeTests {
    @Test func decodesLifecycle() throws {
        let json = #"""
        {"overall":{"avg_hours":4.2,"min_hours":1.0,"max_hours":9.0,"count":3},
         "by_engineer":[{"user_id":"u1","name":"Sam","avg_hours":3.5,"count":2}]}
        """#
        let l = try RMDecode.decode(DashboardLifecycle.self, json)
        #expect(l.overall.count == 3)
        #expect(l.byEngineer?.first?.name == "Sam")
    }

    @Test func decodesWithoutEngineerBreakdown() throws {
        let json = #"""
        {"overall":{"avg_hours":0,"min_hours":0,"max_hours":0,"count":0}}
        """#
        let l = try RMDecode.decode(DashboardLifecycle.self, json)
        #expect(l.byEngineer == nil)
    }
}
