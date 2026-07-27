//
//  OrderEnumFallbackTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

/// These four are decoded straight into properties on Order, so an
/// unrecognised value throws and fails the whole response - which is how the
/// Orders page went down on 2026-07-25. The worker ships without us and can
/// add a value any day; the app must degrade, never throw.
struct OrderEnumFallbackTests {
    private struct ItemW: Decodable { let v: OrderItemType }
    private struct PayW: Decodable { let v: PaymentMethod }
    private struct SigW: Decodable { let v: SignatureType }
    private struct AuthW: Decodable { let v: AuthorisationType }

    /// The one with a live gap: 'service' exists in order_items today and had
    /// no Swift case, so an order containing one could not be read.
    @Test func orderItemTypeReadsService() throws {
        #expect(try RMDecode.decode(ItemW.self, #"{"v":"service"}"#).v == .service)
    }

    @Test func everyKnownValueStillDecodes() throws {
        #expect(try RMDecode.decode(ItemW.self, #"{"v":"repair"}"#).v == .repair)
        #expect(try RMDecode.decode(PayW.self, #"{"v":"bank_transfer"}"#).v == .bankTransfer)
        #expect(try RMDecode.decode(SigW.self, #"{"v":"drop_off"}"#).v == .dropOff)
        #expect(try RMDecode.decode(AuthW.self, #"{"v":"pre_authorised"}"#).v == .preAuthorised)
    }

    @Test func unknownValuesFallBackRatherThanThrowing() throws {
        #expect(try RMDecode.decode(ItemW.self, #"{"v":"warranty_claim"}"#).v == .unknown)
        #expect(try RMDecode.decode(PayW.self, #"{"v":"crypto"}"#).v == .unknown)
        #expect(try RMDecode.decode(SigW.self, #"{"v":"handover"}"#).v == .unknown)
        #expect(try RMDecode.decode(AuthW.self, #"{"v":"sms"}"#).v == .unknown)
    }

    @Test func sentinelsCannotCollideWithABackendValue() {
        #expect(OrderItemType.unknown.rawValue == "__unknown__")
        #expect(PaymentMethod.unknown.rawValue == "__unknown__")
        #expect(SignatureType.unknown.rawValue == "__unknown__")
        #expect(AuthorisationType.unknown.rawValue == "__unknown__")
    }

    /// PaymentMethod and SignatureType drive real pickers
    /// (OrderPaymentFormSheet, CustomerSignatureView). Offering staff
    /// "Unknown" as a payment method would be a defect introduced by the fix.
    @Test func pickersDoNotOfferTheFallback() {
        #expect(!PaymentMethod.allCases.contains(.unknown))
        #expect(!SignatureType.allCases.contains(.unknown))
        #expect(PaymentMethod.allCases.count == 6)
        #expect(SignatureType.allCases.count == 3)
    }

    /// A whole order's items must survive one line the app cannot read.
    @Test func oneUnreadableItemDoesNotPoisonTheOrder() throws {
        let json = #"[{"v":"repair"},{"v":"warranty_claim"},{"v":"service"}]"#
        let rows = try RMDecode.decode([ItemW].self, json)
        #expect(rows.count == 3)
        #expect(rows[1].v == .unknown)
    }
}
