import Testing
import Foundation
@testable import Repair_Minder

struct DeviceActionRequestTests {
    private func encoder() -> JSONEncoder { let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; return e }

    @Test func encodesToStatusKey() throws {
        let req = DeviceActionRequest(toStatus: "in_progress", notes: nil, context: .devicePage)
        let s = String(data: try encoder().encode(req), encoding: .utf8)!
        #expect(s.contains("\"to_status\":\"in_progress\""))
        #expect(!s.contains("\"action\""))
    }
}
