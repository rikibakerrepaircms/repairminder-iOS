//
//  PortalStageDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

/// The three fields the portal stage rules need, on both models.
///
/// Guards the decode trap that has bitten here before: a property written
/// `let x: T? = nil` compiles, keeps the memberwise init source-compatible, and is
/// silently dropped from the synthesised `Decodable` conformance. The build is green
/// and the field is nil forever.
///
/// `CustomerEnquiryDetail` is `GET /api/customer/enquiries/:ticketId` and
/// `CustomerOrderDetail` is `GET /api/customer/orders/:orderId` - the two customer
/// portal detail models the plan calls "CustomerEnquiry" and "CustomerOrder".
struct PortalStageDecodeTests {

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    /// The smallest body CustomerOrderDetail will accept, so the fulfilment test
    /// varies only that one field.
    private func orderJSON(fulfilment: String?) -> String {
        let field = fulfilment.map { "\"fulfilment\": \"\($0)\"," } ?? ""
        return """
        {
          "id": "o1",
          "ticket_number": 100002606,
          "status": "in_progress",
          \(field)
          "devices": [],
          "items": [],
          "totals": {
            "subtotal": 0, "vat_total": 0, "grand_total": 0
          },
          "messages": []
        }
        """
    }

    @Test("the enquiry carries whether we have the device")
    func enquiryCarriesStage() throws {
        let json = #"{"ticket_number":100002606,"device_with_us":true}"#
        let enquiry = try decoder.decode(CustomerEnquiryDetail.self, from: Data(json.utf8))
        #expect(enquiry.deviceWithUs == true)
    }

    @Test("an older payload without the field decodes, and claims nothing")
    func enquiryToleratesAbsence() throws {
        let json = #"{"ticket_number":100002606}"#
        let enquiry = try decoder.decode(CustomerEnquiryDetail.self, from: Data(json.utf8))
        #expect(enquiry.deviceWithUs == nil)
    }

    @Test("the order carries the route the customer chose")
    func orderCarriesRoute() throws {
        let order = try decoder.decode(CustomerOrderDetail.self, from: Data(orderJSON(fulfilment: "collection").utf8))
        #expect(order.fulfilment == "collection")
    }

    @Test("an older order payload without fulfilment decodes, and claims nothing")
    func orderToleratesAbsentFulfilment() throws {
        let order = try decoder.decode(CustomerOrderDetail.self, from: Data(orderJSON(fulfilment: nil).utf8))
        #expect(order.fulfilment == nil)
    }

    @Test("the order carries what the seller declared, so it survives book-in")
    func orderCarriesSellDeclaration() throws {
        let json = """
        {
          "id": "o1",
          "ticket_number": 100002606,
          "status": "in_progress",
          "sell_declaration": { "condition": "Good", "confirmed": [], "not_confirmed": [] },
          "devices": [],
          "items": [],
          "totals": {
            "subtotal": 0, "vat_total": 0, "grand_total": 0
          },
          "messages": []
        }
        """
        let order = try decoder.decode(CustomerOrderDetail.self, from: Data(json.utf8))
        #expect(order.sellDeclaration?.condition == "Good")
    }
}
