import Testing
import Foundation
@testable import Repair_Minder

struct UserRoleDecodeTests {
    private struct Wrap: Decodable { let role: UserRole }
    @Test func knownRoleDecodes() throws {
        #expect(try RMDecode.decode(Wrap.self, #"{"role":"admin"}"#).role == .admin)
    }
    @Test func unknownRoleFallsBack() throws {
        #expect(try RMDecode.decode(Wrap.self, #"{"role":"superuser"}"#).role == .unknown)
    }
    @Test func unknownExcludedFromAllCases() {
        #expect(!UserRole.allCases.contains(.unknown))
    }
}
