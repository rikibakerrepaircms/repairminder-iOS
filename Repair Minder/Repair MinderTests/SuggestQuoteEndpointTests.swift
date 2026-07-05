import XCTest
@testable import Repair_Minder

/// The suggest-quote start (POST) and poll (GET) hit the SAME path; only the
/// HTTP method differs — mirroring the generate/rewrite job endpoints.
final class SuggestQuoteEndpointTests: XCTestCase {
    func testSuggestQuoteStartIsPost() {
        let ep = APIEndpoint.ticketSuggestQuote(id: "42")
        XCTAssertEqual(ep.path, "/api/tickets/42/macro/suggest-quote")
        XCTAssertEqual(ep.method, .post)
    }

    func testSuggestQuoteStatusIsGet() {
        let ep = APIEndpoint.ticketSuggestQuoteStatus(id: "42")
        XCTAssertEqual(ep.path, "/api/tickets/42/macro/suggest-quote")
        XCTAssertEqual(ep.method, .get)
    }
}
