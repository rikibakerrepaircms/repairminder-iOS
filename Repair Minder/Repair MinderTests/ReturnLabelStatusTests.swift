//
//  ReturnLabelStatusTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

/// ReturnLabelStatus.resolve is pure (HTTP status + a decoded envelope in,
/// a state out) and exported so the status-code mapping is tested directly
/// against real HTTP codes and envelope shapes, matching this test target's
/// existing convention of decoding real JSON via RMDecode rather than
/// standing up network mocks - see TicketBuybackLabelsDecodeTests.swift.
struct ReturnLabelStatusTests {

    private func envelope(_ json: String) throws -> APIResponse<CustomerReturnLabel> {
        try RMDecode.decode(APIResponse<CustomerReturnLabel>.self, json)
    }

    @Test func resolvesReadyOnTwoHundredWithALabel() throws {
        let response = try envelope(#"""
        {"success":true,"data":{"tracking_number":"ZL1","service_code":"CRL1",
         "created_at":"2026-08-01 00:00:00","expires_at":"2026-09-01 00:00:00","pdf_url":"/x.pdf"}}
        """#)
        let status = try ReturnLabelStatus.resolve(httpStatus: 200, response: response)
        guard case .ready(let label) = status else { Issue.record("expected .ready"); return }
        #expect(label.trackingNumber == "ZL1")
    }

    @Test func resolvesPendingOnTwoOhTwo() throws {
        let response = try envelope(#"{"success":true,"data":null}"#)
        #expect(try ReturnLabelStatus.resolve(httpStatus: 202, response: response) == .pending)
    }

    @Test func resolvesRejectedOnFourOhNineWithTheRejectedCode() throws {
        let response = try envelope(#"{"success":false,"error":"x","code":"LABEL_REQUEST_REJECTED"}"#)
        #expect(try ReturnLabelStatus.resolve(httpStatus: 409, response: response) == .rejected)
    }

    @Test func resolvesNoneOnFourOhFour() throws {
        let response = try envelope(#"{"success":false,"error":"No label has been created yet"}"#)
        #expect(try ReturnLabelStatus.resolve(httpStatus: 404, response: response) == .none)
    }

    @Test func throwsOnFourTwoTwoAddressRequired() throws {
        let response = try envelope(#"{"success":false,"error":"x","code":"ADDRESS_REQUIRED"}"#)
        #expect(throws: APIError.self) {
            _ = try ReturnLabelStatus.resolve(httpStatus: 422, response: response)
        }
    }

    @Test func fourOhNineWithoutTheRejectedCodeThrowsRatherThanSilentlyBecomingRejected() throws {
        let response = try envelope(#"{"success":false,"error":"some other conflict"}"#)
        #expect(throws: APIError.self) {
            _ = try ReturnLabelStatus.resolve(httpStatus: 409, response: response)
        }
    }
}
