//
//  TicketBuybackLabelsDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct TicketBuybackLabelsDecodeTests {

    @Test func decodesTheLabelSummary() throws {
        let json = #"""
        {"id":"t1","ticket_number":100000001,"subject":"x","status":"open",
         "ticket_type":"lead","created_at":"2026-07-27 09:00:00",
         "updated_at":"2026-07-27 09:00:00",
         "buyback_labels":{"has_return_label":true,"has_outbound_label":false,
                           "packaging_requested_at":null}}
        """#
        let t = try RMDecode.decode(Ticket.self, json)
        #expect(t.buybackLabels?.hasReturnLabel == true)
        #expect(t.buybackLabels?.hasOutboundLabel == false)
        #expect(t.buybackLabels?.packagingRequestedAt == nil)
    }

    /// Most tickets have no labels at all, and the key is absent rather than
    /// null. A required property here would fail the whole enquiries page.
    @Test func toleratesTheKeyBeingAbsent() throws {
        let json = #"""
        {"id":"t1","ticket_number":100000001,"subject":"x","status":"open",
         "ticket_type":"lead","created_at":"2026-07-27 09:00:00",
         "updated_at":"2026-07-27 09:00:00"}
        """#
        #expect(try RMDecode.decode(Ticket.self, json).buybackLabels == nil)
    }
}
