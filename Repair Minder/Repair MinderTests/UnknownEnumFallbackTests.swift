//
//  UnknownEnumFallbackTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

/// Takes a real payload, rewrites one enum field to a value that does not
/// exist, and asserts the page still decodes.
///
/// This is the assertion FixtureDecodeTests cannot make. Decoding a captured
/// payload proves the models fit the rows that happened to exist on capture
/// day; it says nothing about the rows the worker will send next week. If
/// someone removes UnknownDefaultable from an enum, this goes red and the
/// plain decode test does not notice.
struct UnknownEnumFallbackTests {
    private struct ArrayEnv<T: Decodable>: Decodable { let data: T }

    /// Rewrite every occurrence of `key` in the fixture to `value`.
    private func mutate(_ name: String, key: String, to value: String) throws -> Data {
        let obj = try JSONSerialization.jsonObject(with: Fixtures.data(name))
        func walk(_ node: Any) -> Any {
            if let a = node as? [Any] { return a.map(walk) }
            if let d = node as? [String: Any] {
                var out: [String: Any] = [:]
                for (k, v) in d { out[k] = (k == key && v is String) ? value : walk(v) }
                return out
            }
            return node
        }
        return try JSONSerialization.data(withJSONObject: walk(obj))
    }

    /// The exact shape of the 2026-07-25 outage: one unreadable intake method
    /// on a real orders page.
    @Test func anUnknownIntakeMethodDoesNotBreakTheOrdersPage() throws {
        let data = try mutate("orders", key: "intake_method", to: "drone_drop")
        let env = try RMDecode.decoder().decode(ArrayEnv<[Order]>.self, from: data)
        #expect(env.data.count > 0)
        #expect(env.data.allSatisfy { $0.intakeMethod == .unknown })
    }

    @Test func anUnknownOrderStatusDoesNotBreakTheOrdersPage() throws {
        let data = try mutate("orders", key: "status", to: "teleported")
        let env = try RMDecode.decoder().decode(ArrayEnv<[Order]>.self, from: data)
        #expect(env.data.count > 0)
    }

    @Test func anUnknownPaymentStatusDoesNotBreakTheOrdersPage() throws {
        let data = try mutate("orders", key: "payment_status", to: "part_settled")
        let env = try RMDecode.decoder().decode(ArrayEnv<[Order]>.self, from: data)
        #expect(env.data.count > 0)
    }

    @Test func anUnknownTicketStatusDoesNotBreakTheEnquiriesPage() throws {
        struct Page: Decodable { let tickets: [Ticket] }
        struct Env: Decodable { let data: Page }
        let data = try mutate("tickets", key: "status", to: "escalated_to_legal")
        let env = try RMDecode.decoder().decode(Env.self, from: data)
        #expect(env.data.tickets.count > 0)
    }

    /// The devices page is safe by a DIFFERENT mechanism, and this pins that
    /// mechanism rather than pretending it is the same one.
    ///
    /// `DeviceListItem.status` is a plain `String`, and the enum is produced by
    /// a computed property with its own `?? .deviceReceived`. No enum is in the
    /// decode path at all, so an unknown status could never have thrown here,
    /// before or after this work.
    ///
    /// An earlier version of this test asserted only that the page still
    /// decoded, which was true before the hardening too - it guarded nothing
    /// while reading as though it did. Asserting the fallback VALUE is what
    /// makes it fail if someone ever retypes `status` as a bare enum.
    @Test func anUnknownDeviceStatusFallsBackOnTheDevicesPage() throws {
        let data = try mutate("devices", key: "status", to: "in_orbit")
        let env = try RMDecode.decoder().decode(ArrayEnv<[DeviceListItem]>.self, from: data)
        #expect(env.data.count > 0)
        #expect(env.data.allSatisfy { $0.status == "in_orbit" },
                "status must decode as a raw String, not an enum")
        #expect(env.data.allSatisfy { $0.deviceStatus == .deviceReceived },
                "the computed property is where the fallback lives")
    }
}
