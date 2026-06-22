import Testing
import Foundation
@testable import Repair_Minder

/// Decoder configured exactly like APIClient, for feeding captured prod JSON
/// (the `data` payload of the envelope) into production models in tests.
enum RMDecode {
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }
    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try decoder().decode(type, from: Data(json.utf8))
    }
}

struct RMDecodeSelfTest {
    private struct Probe: Decodable { let aB: Int }
    @Test func convertsSnakeCase() throws {
        let p = try RMDecode.decode(Probe.self, #"{"a_b":7}"#)
        #expect(p.aB == 7)
    }
}
