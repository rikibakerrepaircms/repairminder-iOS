import Testing
import Foundation
@testable import Repair_Minder

struct QuoteSuggestionDecodeTests {
    // Decodes the `data` payload of a GET /macro/suggest-quote poll when done
    // with a field suggestion (snake_case → camelCase via the app decoder).
    @Test func decodesSuggestionResult() throws {
        let json = #"""
        {"status":"done","result":{
          "suggestion":{"device_type":"iPhone 14 Pro","repair_type":"Screen Replacement","price":"149.99","product_name":"iPhone 14 Pro Screen","sku":"SCR-14P","confidence":"high"},
          "composed_email":null,
          "matches":[{"sku":"SCR-14P","name":"iPhone 14 Pro Screen","price":"149.99"}],
          "reason":"match"}}
        """#
        let status = try RMDecode.decode(SuggestQuoteJobStatus.self, json)
        #expect(status.status == "done")
        #expect(status.result?.suggestion?.deviceType == "iPhone 14 Pro")
        #expect(status.result?.suggestion?.price == "149.99")
        #expect(status.result?.composedEmail == nil)
        #expect(status.result?.matches?.count == 1)
    }

    // Decodes a composed-email result (multi-tier quote).
    @Test func decodesComposedEmailResult() throws {
        let json = #"""
        {"status":"done","result":{
          "suggestion":null,
          "composed_email":{"subject":"Your repair quote","body":"Premium: £149\nAftermarket: £99"},
          "matches":[{"sku":"A","name":"Premium","price":"149"},{"sku":"B","name":"Aftermarket","price":"99"}],
          "reason":"match"}}
        """#
        let status = try RMDecode.decode(SuggestQuoteJobStatus.self, json)
        #expect(status.result?.composedEmail?.subject == "Your repair quote")
        #expect(status.result?.matches?.count == 2)
    }

    // Decodes the "no catalog" success result (suggestion null, reason set).
    @Test func decodesNoServiceCatalogResult() throws {
        let json = #"""
        {"status":"done","result":{"suggestion":null,"composed_email":null,"matches":[],"reason":"no_service_catalog"}}
        """#
        let status = try RMDecode.decode(SuggestQuoteJobStatus.self, json)
        #expect(status.result?.suggestion == nil)
        #expect(status.result?.reason == "no_service_catalog")
    }

    // Decodes the POST-start payload (running, no result).
    @Test func decodesRunningStart() throws {
        let json = #"{"job_id":"abc","kind":"suggest_quote","status":"running","started_at":"2026-07-05T00:00:00Z"}"#
        let status = try RMDecode.decode(SuggestQuoteJobStatus.self, json)
        #expect(status.status == "running")
        #expect(status.result == nil)
    }
}
