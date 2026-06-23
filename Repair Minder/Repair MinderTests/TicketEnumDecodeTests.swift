import Testing
import Foundation
@testable import Repair_Minder

struct TicketEnumDecodeTests {
    private struct T: Decodable { let v: TicketType }
    private struct M: Decodable { let v: MessageType }
    private struct E: Decodable { let v: ExecutionStatus }
    private struct S: Decodable { let v: TicketStatus }

    @Test func ticketTypeUnknown() throws {
        #expect(try RMDecode.decode(T.self, #"{"v":"wholesale"}"#).v == .unknown)
    }
    @Test func messageTypeUnknown() throws {
        #expect(try RMDecode.decode(M.self, #"{"v":"webhook"}"#).v == .unknown)
    }
    @Test func executionStatusUnknown() throws {
        #expect(try RMDecode.decode(E.self, #"{"v":"archived"}"#).v == .unknown)
    }
    @Test func knownStillDecodes() throws {
        #expect(try RMDecode.decode(T.self, #"{"v":"lead"}"#).v == .lead)
        #expect(try RMDecode.decode(M.self, #"{"v":"note"}"#).v == .note)
        #expect(try RMDecode.decode(E.self, #"{"v":"active"}"#).v == .active)
    }

    // MARK: - TicketStatus (sweep 9.1)
    @Test func ticketStatusUnknownFallsToUnknown() throws {
        #expect(try RMDecode.decode(S.self, #"{"v":"archived"}"#).v == .unknown)
    }
    @Test func ticketStatusKnownDecodes() throws {
        #expect(try RMDecode.decode(S.self, #"{"v":"open"}"#).v == .open)
        #expect(try RMDecode.decode(S.self, #"{"v":"pending"}"#).v == .pending)
        #expect(try RMDecode.decode(S.self, #"{"v":"resolved"}"#).v == .resolved)
        #expect(try RMDecode.decode(S.self, #"{"v":"closed"}"#).v == .closed)
    }
    @Test func ticketStatusAllCasesExcludesUnknown() {
        #expect(!TicketStatus.allCases.contains(.unknown))
    }
}
