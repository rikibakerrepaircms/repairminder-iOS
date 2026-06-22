//
//  BuybackStatusDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct BuybackStatusDecodeTests {
    private struct W: Decodable { let v: BuybackStatus }
    @Test func unknownFallsBack() throws {
        #expect(try RMDecode.decode(W.self, #"{"v":"scrapped"}"#).v == .unknown)
    }
    @Test func knownDecodes() throws {
        #expect(try RMDecode.decode(W.self, #"{"v":"for_sale"}"#).v == .forSale)
    }
}
