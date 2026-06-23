import Testing
import Foundation
@testable import Repair_Minder

private enum Sample: String, UnknownDefaultable {
    case a, b, unknown
    static var unknownFallback: Sample { .unknown }
}

struct UnknownDefaultableTests {
    private struct Wrap: Decodable { let v: Sample }

    @Test func knownValueDecodes() throws {
        let w = try JSONDecoder().decode(Wrap.self, from: Data(#"{"v":"a"}"#.utf8))
        #expect(w.v == .a)
    }
    @Test func unknownValueFallsBack() throws {
        let w = try JSONDecoder().decode(Wrap.self, from: Data(#"{"v":"zzz"}"#.utf8))
        #expect(w.v == .unknown)
    }
}
