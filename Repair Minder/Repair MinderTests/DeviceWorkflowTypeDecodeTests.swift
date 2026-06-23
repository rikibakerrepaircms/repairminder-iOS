import Testing
import Foundation
@testable import Repair_Minder

struct DeviceWorkflowTypeDecodeTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }
    @Test func unknownWorkflowTypeFallsBack() throws {
        let v = try decoder().decode(DeviceWorkflowType.self, from: #""trade_in""#.data(using: .utf8)!)
        #expect(v == DeviceWorkflowType.unknownFallback)
    }
}
