import Testing
import Foundation
@testable import Repair_Minder

struct DeviceActionDecodeTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }

    @Test func decodesActionsWithArrayRequiresInputAndNull() throws {
        let json = #"""
        {"current_status":"ready_to_quote","workflow_type":"repair","available_actions":[
          {"to_status":"awaiting_authorisation","label":"Send quote","display_label":"Quote","requires_confirmation":true,"requires_input":["quote_items_confirmed"]},
          {"to_status":"in_progress","label":"Start repair","display_label":"Start","requires_confirmation":false,"requires_input":null}
        ]}
        """#.data(using: .utf8)!
        let r = try decoder().decode(DeviceActionsResponse.self, from: json)
        #expect(r.availableActions.count == 2)
        #expect(r.availableActions[0].toStatus == "awaiting_authorisation")
        #expect(r.availableActions[0].isDevicePageAction == nil)
        #expect(r.availableActions[0].requiresConfirmation == true)
        #expect(r.availableActions[0].requiresInput == ["quote_items_confirmed"])
        #expect(r.availableActions[1].requiresInput == nil)
    }
}
