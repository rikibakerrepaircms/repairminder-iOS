import Testing
@testable import Repair_Minder

struct DeviceActionEndpointTests {
    @Test func actionsPathIsDeviceScoped() {
        let ep = APIEndpoint.deviceActions(orderId: "ord1", deviceId: "dev1")
        #expect(ep.path == "/api/devices/dev1/actions")
    }
    @Test func executeActionPathIsDeviceScoped() {
        let ep = APIEndpoint.executeDeviceAction(orderId: "ord1", deviceId: "dev1")
        #expect(ep.path == "/api/devices/dev1/action")
    }
}
