import Testing
import Foundation
@testable import Repair_Minder

struct DeviceActionDecodeTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }

    @Test func decodesHandlerShapeWithoutIsDevicePageAction() throws {
        let json = #"""
        {"current_status":"diagnosis","workflow_type":"repair","available_actions":[
          {"to_status":"in_progress","label":"Start repair","display_label":"Start","requires_confirmation":true,"requires_input":false}
        ]}
        """#.data(using: .utf8)!
        let r = try decoder().decode(DeviceActionsResponse.self, from: json)
        #expect(r.availableActions.count == 1)
        #expect(r.availableActions[0].toStatus == "in_progress")
        #expect(r.availableActions[0].isDevicePageAction == nil)
        #expect(r.availableActions[0].requiresConfirmation == true)
    }
}
