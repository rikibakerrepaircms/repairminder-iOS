//
//  SellerIdOutstandingDecodeTests.swift
//  Repair MinderTests
//
//  `seller_id_outstanding` drives the one banner allowed to outrank the offer on a
//  customer's order. It arrived after the model did, so the decode has to survive its
//  absence: a Worker predating it, and every non-buyback order, simply omit the key.
//

import Testing
import Foundation
@testable import Repair_Minder

struct SellerIdOutstandingDecodeTests {

    /// The smallest body CustomerOrderDetail will accept, so each test varies one thing.
    private func json(sellerIdOutstanding: String?) -> String {
        let field = sellerIdOutstanding.map { "\"seller_id_outstanding\": \($0)," } ?? ""
        return """
        {
          "id": "ord_1",
          "ticket_number": 100002867,
          "status": "in_progress",
          "created_at": "2026-08-22 09:00:00",
          \(field)
          "devices": [],
          "items": [],
          "totals": {
            "subtotal": 0, "vat_total": 0, "grand_total": 0,
            "deposits_paid": 0, "final_payments_paid": 0,
            "amount_paid": 0, "balance_due": 0
          },
          "messages": []
        }
        """
    }

    @Test func decodesTrue() throws {
        let order = try RMDecode.decode(CustomerOrderDetail.self, json(sellerIdOutstanding: "true"))
        #expect(order.sellerIdOutstanding == true)
    }

    @Test func decodesFalse() throws {
        let order = try RMDecode.decode(CustomerOrderDetail.self, json(sellerIdOutstanding: "false"))
        #expect(order.sellerIdOutstanding == false)
    }

    /// The case that matters most. A missing key must decode to nil, not throw - every
    /// repair order omits it, and so does any response from a Worker deployed before
    /// the field existed. A throw here would break the whole order screen.
    @Test func absentDecodesToNilRatherThanThrowing() throws {
        let order = try RMDecode.decode(CustomerOrderDetail.self, json(sellerIdOutstanding: nil))
        #expect(order.sellerIdOutstanding == nil)
    }

    /// nil is NOT "we are waiting on them". The banner checks `== true` precisely so an
    /// absent field cannot nag a repair customer for identity documents.
    @Test func nilIsNotTreatedAsOutstanding() throws {
        let order = try RMDecode.decode(CustomerOrderDetail.self, json(sellerIdOutstanding: nil))
        #expect((order.sellerIdOutstanding == true) == false)
    }
}
