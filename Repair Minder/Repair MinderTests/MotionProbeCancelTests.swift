import Testing
import Foundation
@testable import Repair_Minder

@MainActor
struct MotionProbeCancelTests {
    @Test func accelAliveReturnsOnSimulator() async {
        // On the simulator the probe returns nil immediately; this guards the early-return path
        // and that the call is non-hanging (CI runs on sim).
        let probe = MotionAliveProbeCM()
        let r = await probe.accelerometerAlive(windowMs: 600)
        #expect(r == nil)
    }
    @Test func cancelledTaskDoesNotHang() async {
        let probe = MotionAliveProbeCM()
        let task = Task { await probe.accelerometerAlive(windowMs: 5000) }
        task.cancel()
        let r = await task.value      // must return well under the 5s window
        #expect(r == nil)
    }
}
