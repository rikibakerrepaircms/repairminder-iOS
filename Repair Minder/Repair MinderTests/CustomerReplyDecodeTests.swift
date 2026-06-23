//
//  CustomerReplyDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct CustomerReplyDecodeTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }

    /// Real `data` payload from POST /api/customer/orders/:id/reply (created_at is toISOString() with fractional seconds).
    /// Must decode without a dateDecodingStrategy — the response is discarded by the caller and Date parsing
    /// via .iso8601 fails on fractional-second timestamps on iOS 17.6–25 (old Foundation, not swift-foundation).
    @Test func replyResponseDecodesRealPayload() throws {
        let json = #"{"message_id":"msg_123","postmark_message_id":null,"type":"outbound","body_html":"<div>hi</div>","body_text":"hi","created_at":"2026-06-23T10:00:00.000Z"}"#.data(using: .utf8)!
        let r = try decoder().decode(CustomerReplyResponse.self, from: json)
        #expect(r.messageId == "msg_123")
        #expect(r.createdAt == "2026-06-23T10:00:00.000Z")
    }

    @Test func replyResponseDecodesWithMissingFields() throws {
        let json = #"{}"#.data(using: .utf8)!
        let r = try decoder().decode(CustomerReplyResponse.self, from: json)
        #expect(r.messageId == nil)
    }
}
