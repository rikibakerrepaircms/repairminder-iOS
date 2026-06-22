import Testing
import CoreGraphics
@testable import Repair_Minder

@MainActor final class FakeDepth: DepthProbe {
    /// Fire `frameCount` depth-frame ticks synchronously; image callback is ignored (no hardware).
    var frameCount: Int
    init(frameCount: Int = 3) { self.frameCount = frameCount }
    func start(onDepthFrame: @escaping () -> Void, onDepthImage: @escaping (CGImage) -> Void) {
        for _ in 0..<frameCount { onDepthFrame() }
    }
    func stop() {}
}

struct DepthViewModelTests {
    // requiredSeconds: 0 collapses the time gate so the test passes immediately once minFrames
    // are delivered — no real Timer needed.

    @Test @MainActor func truedepthPassesOnFrames() {
        let m = DepthViewModel(probe: FakeDepth(frameCount: 30), id: "truedepth", name: "TrueDepth Camera",
                               detailKey: "depth_frames", requiredSeconds: 0, minFrames: 30)
        m.start()
        #expect(m.outcome?.status == .pass)
        #expect(m.outcome?.details?["depth_frames"] == "30")
    }

    @Test @MainActor func lidarPassesOnFrames() {
        let m = DepthViewModel(probe: FakeDepth(frameCount: 30), id: "lidar", name: "LiDAR Scanner",
                               detailKey: "scene_depth_frames", requiredSeconds: 0, minFrames: 30)
        m.start()
        #expect(m.outcome?.status == .pass)
        #expect(m.outcome?.details?["scene_depth_frames"] == "30")
    }

    @Test @MainActor func doesNotPassBelowMinFrames() {
        // Only 5 frames — below minFrames:30, so no pass even with requiredSeconds:0.
        let m = DepthViewModel(probe: FakeDepth(frameCount: 5), id: "truedepth", name: "TrueDepth Camera",
                               detailKey: "depth_frames", requiredSeconds: 0, minFrames: 30)
        m.start()
        #expect(m.outcome == nil)
        #expect(m.frames == 5)
    }

    @Test @MainActor func failIfUnresolvedSetsFailOutcome() {
        let m = DepthViewModel(probe: FakeDepth(frameCount: 0), id: "truedepth", name: "TrueDepth Camera",
                               detailKey: "depth_frames", requiredSeconds: 3, minFrames: 30)
        // No frames fired — outcome is nil. Watchdog fires.
        m.failIfUnresolved()
        #expect(m.outcome?.status == .fail)
        #expect(m.outcome?.details?["reason"] == "no_depth_signal")
    }

    @Test @MainActor func failIfUnresolvedIsNoopAfterPass() {
        let m = DepthViewModel(probe: FakeDepth(frameCount: 30), id: "truedepth", name: "TrueDepth Camera",
                               detailKey: "depth_frames", requiredSeconds: 0, minFrames: 30)
        m.start()
        #expect(m.outcome?.status == .pass)
        // Calling watchdog after pass must not overwrite the pass.
        m.failIfUnresolved()
        #expect(m.outcome?.status == .pass)
    }
}
