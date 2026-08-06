//
//  FixtureDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

/// Decodes captured production payloads through the real models, so model or
/// API drift fails here rather than in front of a user.
///
/// This is necessary and not sufficient - see UnknownEnumFallbackTests. It
/// proves the models fit the rows that existed on capture day, and it would
/// have been green the day before the Orders page went down.
struct FixtureDecodeTests {
    private struct ArrayEnv<T: Decodable>: Decodable { let data: T }
    private struct TicketsPage: Decodable { let tickets: [Ticket] }
    private struct ClientsPage: Decodable { let clients: [Client] }
    private struct TicketsEnv: Decodable { let data: TicketsPage }
    private struct ClientsEnv: Decodable { let data: ClientsPage }

    @Test func ordersDecode() throws {
        let env = try RMDecode.decoder().decode(ArrayEnv<[Order]>.self, from: Fixtures.data("orders"))
        #expect(env.data.count > 0)
    }

    @Test func devicesDecode() throws {
        let env = try RMDecode.decoder().decode(ArrayEnv<[DeviceListItem]>.self, from: Fixtures.data("devices"))
        #expect(env.data.count > 0)
    }

    /// tickets nests its array under data.tickets, beside statusCounts.
    @Test func ticketsDecode() throws {
        let env = try RMDecode.decoder().decode(TicketsEnv.self, from: Fixtures.data("tickets"))
        #expect(env.data.tickets.count > 0)
    }

    /// clients nests its array under data.clients, beside pagination.
    @Test func clientsDecode() throws {
        let env = try RMDecode.decoder().decode(ClientsEnv.self, from: Fixtures.data("clients"))
        #expect(env.data.clients.count > 0)
    }
}
