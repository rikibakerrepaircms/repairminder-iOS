import Testing
import Foundation
@testable import Repair_Minder

struct ChecklistDecodeTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }

    struct Holder: Decodable { let checklist: FlexibleChecklist? }

    @Test func decodesNonEmptyArrayAndComputesProgress() throws {
        let json = #"""
        {"checklist":[
          {"key":"a","label":"Backup","completed":true,"required":true},
          {"key":"b","label":"Diagnose","completed":false,"required":true}
        ]}
        """#.data(using: .utf8)!
        let h = try decoder().decode(Holder.self, from: json)
        #expect(h.checklist?.value?.items.count == 2)
        #expect(h.checklist?.value?.percentComplete == 50)
    }

    @Test func emptyArrayStaysNil() throws {
        let json = #"{"checklist":[]}"#.data(using: .utf8)!
        let h = try decoder().decode(Holder.self, from: json)
        #expect(h.checklist?.value == nil)
    }
}
