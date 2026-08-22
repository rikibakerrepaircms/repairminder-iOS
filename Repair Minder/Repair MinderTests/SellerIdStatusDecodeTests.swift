//
//  SellerIdStatusDecodeTests.swift
//  Repair MinderTests
//
//  `seller_id_status` drives the one banner allowed to outrank the offer on a
//  customer's order. It arrived after the model did, so the decode has to survive its
//  absence: a Worker predating it, and every repair order, simply omit the key.
//
//  It is a String, not an enum, on purpose - a value from a newer Worker must render
//  nothing rather than crash the order screen.
//

import Testing
import Foundation
@testable import Repair_Minder

struct SellerIdStatusDecodeTests {

    /// The smallest body CustomerOrderDetail will accept, so each test varies one thing.
    private func json(sellerIdStatus: String?) -> String {
        let field = sellerIdStatus.map { "\"seller_id_status\": \"\($0)\"," } ?? ""
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

    @Test func decodesAwaitingCustomer() throws {
        let order = try RMDecode.decode(CustomerOrderDetail.self, json(sellerIdStatus: "awaiting_customer"))
        #expect(order.sellerIdStatus == "awaiting_customer")
    }

    /// Uploading is not confirming. This state means the document is with US, and the
    /// banner must still say payment is waiting - just that we are the hold-up.
    @Test func decodesInReview() throws {
        let order = try RMDecode.decode(CustomerOrderDetail.self, json(sellerIdStatus: "in_review"))
        #expect(order.sellerIdStatus == "in_review")
    }

    @Test func decodesConfirmed() throws {
        let order = try RMDecode.decode(CustomerOrderDetail.self, json(sellerIdStatus: "confirmed"))
        #expect(order.sellerIdStatus == "confirmed")
    }

    /// A String, not an enum. A value a newer Worker invents must decode cleanly and
    /// render nothing, rather than throwing and taking the whole order screen with it.
    @Test func anUnknownStatusDecodesRatherThanThrowing() throws {
        let order = try RMDecode.decode(CustomerOrderDetail.self, json(sellerIdStatus: "some_future_state"))
        #expect(order.sellerIdStatus == "some_future_state")
    }

    /// The case that matters most. A missing key must decode to nil, not throw - every
    /// repair order omits it, and so does any response from a Worker deployed before
    /// the field existed. A throw here would break the whole order screen.
    @Test func absentDecodesToNilRatherThanThrowing() throws {
        let order = try RMDecode.decode(CustomerOrderDetail.self, json(sellerIdStatus: nil))
        #expect(order.sellerIdStatus == nil)
    }

    /// nil is NOT "we are waiting on them". The banner matches only the two live
    /// states precisely so an absent field cannot nag a repair customer for ID.
    @Test func nilShowsNothing() throws {
        let order = try RMDecode.decode(CustomerOrderDetail.self, json(sellerIdStatus: nil))
        let shows = order.sellerIdStatus == "awaiting_customer" || order.sellerIdStatus == "in_review"
        #expect(shows == false)
    }
}
