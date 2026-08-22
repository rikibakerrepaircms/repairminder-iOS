//
//  PortalStageTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

/// Whether the app still tells someone to send us a device we already have.
///
/// `deviceIsWithUs` answered `ticketType == "order"` - a staff filing action, not the
/// parcel arriving. A device that had arrived but had not been booked in yet still got
/// "get your device to us"; one booked in early lost its postage label while it was
/// still on the customer's table.
///
/// The server now answers the real question in `device_with_us`. Falling back to SHOWING
/// the card when the server has not answered is deliberate: showing the label to someone
/// who has already posted is untidy, but hiding it from someone who has not leaves them
/// unable to send their device at all.
struct PortalStageTests {

    private func enquiry(deviceWithUs: Bool?, ticketType: String?) throws -> CustomerEnquiryDetail {
        var fields: [String] = ["\"ticket_number\": 100002606"]
        if let deviceWithUs { fields.append("\"device_with_us\": \(deviceWithUs)") }
        if let ticketType { fields.append("\"ticket_type\": \"\(ticketType)\"") }
        let json = "{\(fields.joined(separator: ","))}"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CustomerEnquiryDetail.self, from: Data(json.utf8))
    }

    @Test("the card shows while the device is still with the customer")
    func showsBeforeArrival() throws {
        let e = try enquiry(deviceWithUs: false, ticketType: "lead")
        #expect(e.deviceIsWithUs == false)
    }

    @Test("the card stands down once we have the device and the ticket agrees")
    func hidesAfterArrival() throws {
        // The fourth corner of the matrix: both signals say the device is here. It used
        // to duplicate arrivalIsNotFiling exactly, which is why removing the old
        // implementation turned four tests red instead of the two that were really
        // distinguishing anything.
        let e = try enquiry(deviceWithUs: true, ticketType: "order")
        #expect(e.deviceIsWithUs == true)
    }

    @Test("a converted ticket whose device has NOT arrived still shows the card")
    func filingIsNotArrival() throws {
        // The whole point. ticket_type says order; the parcel is still on their table.
        let e = try enquiry(deviceWithUs: false, ticketType: "order")
        #expect(e.deviceIsWithUs == false)
    }

    @Test("an unconverted ticket whose device HAS arrived stands the card down")
    func arrivalIsNotFiling() throws {
        // The mirror of filingIsNotArrival: the parcel is on the bench and nobody has
        // pressed Convert yet. Reading ticket_type here would keep telling them to post
        // a device we are already holding.
        let e = try enquiry(deviceWithUs: true, ticketType: "lead")
        #expect(e.deviceIsWithUs == true)
    }

    @Test("an older server that does not answer leaves the card showing")
    func safeDefault() throws {
        let e = try enquiry(deviceWithUs: nil, ticketType: "order")
        #expect(e.deviceIsWithUs == false)
    }
}
