//
//  PosStatusDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct PosStatusDecodeTests {
    private struct T: Decodable { let v: PosTransactionStatus }
    private struct L: Decodable { let v: PaymentLinkStatus }
    @Test func txUnknown() throws {
        #expect(try RMDecode.decode(T.self, #"{"v":"reversed"}"#).v == .unknown)
    }
    @Test func linkUnknown() throws {
        #expect(try RMDecode.decode(L.self, #"{"v":"refunded"}"#).v == .unknown)
    }
    @Test func knownDecode() throws {
        #expect(try RMDecode.decode(T.self, #"{"v":"completed"}"#).v == .completed)
        #expect(try RMDecode.decode(L.self, #"{"v":"expired"}"#).v == .expired)
    }
}
