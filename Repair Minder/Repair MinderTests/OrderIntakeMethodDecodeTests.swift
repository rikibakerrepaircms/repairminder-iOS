//
//  OrderIntakeMethodDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

/// The staff Orders page decodes `[Order]` in one pass, so a single row the
/// enum cannot read fails the WHOLE list and the page shows an error rather
/// than 199 good orders and one gap.
///
/// That is what happened live: `intake_method` had no `collection` case, the
/// app's own ConvertEnquiryToOrderSheet has always sent `.collection` on a
/// doorstep pickup, and one such order on 2026-07-25 took the page down.
struct OrderIntakeMethodDecodeTests {
    private struct W: Decodable { let v: IntakeMethod }

    /// The value that broke it. `collection` is in the worker's INTAKE_METHODS
    /// and is what a doorstep conversion writes.
    @Test func collectionDecodes() throws {
        #expect(try RMDecode.decode(W.self, #"{"v":"collection"}"#).v == .collection)
    }

    @Test func knownValuesStillDecode() throws {
        #expect(try RMDecode.decode(W.self, #"{"v":"walk_in"}"#).v == .walkIn)
        #expect(try RMDecode.decode(W.self, #"{"v":"kiosk_sale"}"#).v == .kioskSale)
        #expect(try RMDecode.decode(W.self, #"{"v":"online"}"#).v == .online)
    }

    /// The real defence. Adding `collection` fixes today's row; this is what
    /// stops the NEXT new intake method taking the page down again. The worker
    /// is free to add one without an App Store release, and it must degrade to
    /// a value the app can render instead of throwing.
    @Test func unknownFallsBackRatherThanThrowing() throws {
        #expect(try RMDecode.decode(W.self, #"{"v":"drone_drop"}"#).v == .unknown)
    }

    /// A whole page must survive one unreadable row - the actual failure mode.
    @Test func oneUnreadableRowDoesNotPoisonTheList() throws {
        let json = #"[{"v":"walk_in"},{"v":"drone_drop"},{"v":"collection"}]"#
        let rows = try RMDecode.decode([W].self, json)
        #expect(rows.count == 3)
        #expect(rows[1].v == .unknown)
    }

    /// `Order.intakeMethod` is Optional, and a nullable column with no
    /// server-side backfill sends JSON null.
    @Test func nullIsTolerated() throws {
        struct Opt: Decodable { let v: IntakeMethod? }
        #expect(try RMDecode.decode(Opt.self, #"{"v":null}"#).v == nil)
    }
}
