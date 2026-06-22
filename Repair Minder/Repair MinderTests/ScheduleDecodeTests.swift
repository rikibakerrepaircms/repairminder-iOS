import Testing
import Foundation
@testable import Repair_Minder

struct ScheduleDecodeTests {
    @Test func scheduleItemDecodesNullDate() throws {
        let json = #"""
        {"id":"d1","deviceId":"d1","orderId":"o1","scheduleDate":null,"startMinutes":600,"duration":60,"deviceName":"X","orderNumber":100,"completedAt":null}
        """#
        let item = try RMDecode.decode(ScheduleItemModel.self, json)
        #expect(item.scheduleDate == nil)
        #expect(item.startMinutes == 600)
    }
}
