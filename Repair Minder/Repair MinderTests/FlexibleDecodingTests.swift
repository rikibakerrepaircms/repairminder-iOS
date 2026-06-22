import Testing
import Foundation
@testable import Repair_Minder

struct FlexibleDecodingTests {
    private struct S: Decodable { let v: FlexibleString }
    private struct B: Decodable { let v: FlexibleBool }

    @Test func flexibleStringDecodesInt() throws {
        let s = try JSONDecoder().decode(S.self, from: Data(#"{"v":100000003}"#.utf8))
        #expect(s.v.value == "100000003")
    }
    @Test func flexibleStringDecodesString() throws {
        let s = try JSONDecoder().decode(S.self, from: Data(#"{"v":"abc"}"#.utf8))
        #expect(s.v.value == "abc")
    }
    @Test func flexibleBoolDecodesIntZeroOne() throws {
        let b1 = try JSONDecoder().decode(B.self, from: Data(#"{"v":1}"#.utf8))
        let b0 = try JSONDecoder().decode(B.self, from: Data(#"{"v":0}"#.utf8))
        #expect(b1.v.value == true)
        #expect(b0.v.value == false)
    }
    @Test func flexibleBoolDecodesBool() throws {
        let b = try JSONDecoder().decode(B.self, from: Data(#"{"v":true}"#.utf8))
        #expect(b.v.value == true)
    }
}
