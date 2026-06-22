import Testing
import Foundation
@testable import Repair_Minder

struct StaffLoginDecodeTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }

    @Test func decodesMagicLinkOnlyBranch() throws {
        let json = #"{"requires_magic_link":true,"message":"Use the link"}"#.data(using: .utf8)!
        let r = try decoder().decode(StaffLoginResponse.self, from: json)
        #expect(r.requiresMagicLink == true)
        #expect(r.userId == nil)
    }

    @Test func decodesNormalBranch() throws {
        let json = #"""
        {"requires_two_factor":true,"user_id":"u1","email":"a@b.com",
         "user":{"id":"u1","email":"a@b.com","company_id":"c1"}}
        """#.data(using: .utf8)!
        let r = try decoder().decode(StaffLoginResponse.self, from: json)
        #expect(r.userId == "u1")
        #expect(r.requiresMagicLink == nil)
    }
}
