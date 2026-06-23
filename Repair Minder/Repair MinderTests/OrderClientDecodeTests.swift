//
//  OrderClientDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct OrderClientDecodeTests {
    private struct O: Decodable { let v: OrderStatus }
    @Test func orderStatusUnknown() throws {
        #expect(try RMDecode.decode(O.self, #"{"v":"refunded_partial"}"#).v == .unknown)
    }
    @Test func orderStatusKnown() throws {
        #expect(try RMDecode.decode(O.self, #"{"v":"in_progress"}"#).v == .inProgress)
    }
    @Test func clientDecodesWithNullEmail() throws {
        let json = #"{"id":"c1","first_name":"A","last_name":"B"}"#
        let c = try RMDecode.decode(Client.self, json)
        #expect(c.email == nil)
        #expect(c.id == "c1")
    }
}
