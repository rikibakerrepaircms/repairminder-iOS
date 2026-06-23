import Testing
import Foundation
@testable import Repair_Minder

struct CustomerTicketNumberTests {
    @Test func summaryDecodesStringTicketNumber() throws {
        let json = #"""
        {"id":"o1","ticket_number":"A-100","status":"in_progress","created_at":"2026-02-02T10:00:00Z","devices":[],"totals":{"subtotal":0,"vat_total":0,"grand_total":0}}
        """#
        let s = try RMDecode.decode(CustomerOrderSummary.self, json)
        #expect(s.ticketNumber.value == "A-100")
    }
    @Test func summaryDecodesIntTicketNumber() throws {
        let json = #"""
        {"id":"o1","ticket_number":100000004,"status":"in_progress","created_at":"2026-02-02T10:00:00Z","devices":[],"totals":{"subtotal":0,"vat_total":0,"grand_total":0}}
        """#
        let s = try RMDecode.decode(CustomerOrderSummary.self, json)
        #expect(s.ticketNumber.value == "100000004")
    }
}
