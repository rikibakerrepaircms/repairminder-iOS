//
//  CustomerEnquiryServiceReturnLabelTests.swift
//  Repair MinderTests
//

import XCTest
@testable import Repair_Minder

/// `CustomerEnquiryService.fetchReturnLabel` hits `URLSession.shared` directly and reads the
/// customer token from `CustomerAuthManager.shared` (backed by the real Keychain), same as
/// `BuybackDetailViewModelTests`/`BuybackListViewModelTests`. We stub the network via
/// `StubURLProtocol` and seed/clear a real Keychain *customer* token per test.
///
/// This exists to cover the call-site ordering fix in `fetchReturnLabel`: the 404 check must
/// run BEFORE the JSON decode, so a 404 with a body the decoder can't parse (an edge/WAF
/// interstitial, an empty body, anything a link scanner or prefetcher might receive instead of
/// our JSON envelope) still resolves to `.none` rather than throwing a decode error.
/// `ReturnLabelStatusTests` already covers `ReturnLabelStatus.resolve` itself against a real,
/// well-formed envelope — that is unaffected by this fix and deliberately not duplicated here.
@MainActor
final class CustomerEnquiryServiceReturnLabelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubURLProtocol.self)
        KeychainManager.shared.setCustomerAccessToken("test-customer-access-token")
    }
    override func tearDown() {
        StubURLProtocol.handler = nil
        URLProtocol.unregisterClass(StubURLProtocol.self)
        KeychainManager.shared.clearCustomerTokens()
        super.tearDown()
    }

    /// The regression this fix closes: a 404 whose body is not our JSON envelope (e.g. a
    /// Cloudflare edge/WAF interstitial) must still resolve to `.none`, not throw a decode
    /// error. Before the fix, the decode ran unconditionally ahead of any status-code check.
    func testFetchReturnLabelResolvesNoneOnFourOhFourWithUnparsableBody() async throws {
        StubURLProtocol.handler = { _ in (404, Data("<html>502 Bad Gateway</html>".utf8)) }
        let status = try await CustomerEnquiryService.fetchReturnLabel(ticketId: "t1")
        XCTAssertEqual(status, .none)
    }

    /// Same regression, empty-body case (a bare 404 with no content at all).
    func testFetchReturnLabelResolvesNoneOnFourOhFourWithEmptyBody() async throws {
        StubURLProtocol.handler = { _ in (404, Data()) }
        let status = try await CustomerEnquiryService.fetchReturnLabel(ticketId: "t1")
        XCTAssertEqual(status, .none)
    }

    /// Baseline: a normal 404 with the server's actual JSON error envelope still resolves to
    /// `.none`, same as before the fix — the hoisted check must not change this path.
    func testFetchReturnLabelResolvesNoneOnFourOhFourWithJSONEnvelope() async throws {
        StubURLProtocol.handler = { _ in
            (404, Data(#"{"success":false,"error":"No label has been created yet"}"#.utf8))
        }
        let status = try await CustomerEnquiryService.fetchReturnLabel(ticketId: "t1")
        XCTAssertEqual(status, .none)
    }

    /// Baseline: a real label on 200 still decodes and resolves to `.ready` — the hoisted 404
    /// check must not affect any other status code's path through the decoder.
    func testFetchReturnLabelResolvesReadyOnTwoHundredWithALabel() async throws {
        StubURLProtocol.handler = { _ in
            (200, Data(#"""
            {"success":true,"data":{"tracking_number":"ZL1","service_code":"CRL1",
             "created_at":"2026-08-01 00:00:00","expires_at":"2026-09-01 00:00:00","pdf_url":"/x.pdf"}}
            """#.utf8))
        }
        let status = try await CustomerEnquiryService.fetchReturnLabel(ticketId: "t1")
        guard case .ready(let label) = status else { return XCTFail("expected .ready, got \(status)") }
        XCTAssertEqual(label.trackingNumber, "ZL1")
    }
}
