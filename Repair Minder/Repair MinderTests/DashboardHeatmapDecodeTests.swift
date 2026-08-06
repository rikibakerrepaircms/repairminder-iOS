//
//  DashboardHeatmapDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct DashboardHeatmapDecodeTests {
    @Test func decodes() throws {
        let json = #"""
        {"heatmap":[{"day":4,"hour":9,"count":2}],"maxCount":2}
        """#
        let h = try RMDecode.decode(DashboardHeatmap.self, json)
        #expect(h.heatmap.first?.count == 2)
        #expect(h.maxCount == 2)
    }

    @Test func decodesEmptyHeatmap() throws {
        let json = #"""
        {"heatmap":[],"maxCount":0}
        """#
        let h = try RMDecode.decode(DashboardHeatmap.self, json)
        #expect(h.heatmap.isEmpty)
        #expect(h.maxCount == 0)
    }
}
