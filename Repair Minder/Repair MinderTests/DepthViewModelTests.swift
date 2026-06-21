import Testing
@testable import Repair_Minder

@MainActor final class FakeDepth: DepthProbe {
    func start(onDepthFrame: @escaping () -> Void) { for _ in 0..<3 { onDepthFrame() } }
    func stop() {}
}
struct DepthViewModelTests {
    @Test @MainActor func truedepthPassesOnFrames() {
        let m = DepthViewModel(probe: FakeDepth(), id: "truedepth", name: "TrueDepth Camera", detailKey: "depth_frames")
        m.start()
        #expect(m.outcome?.status == .pass)
        #expect(m.outcome?.details?["depth_frames"] == "3")
    }
    @Test @MainActor func lidarPassesOnFrames() {
        let m = DepthViewModel(probe: FakeDepth(), id: "lidar", name: "LiDAR Scanner", detailKey: "scene_depth_frames")
        m.start()
        #expect(m.outcome?.status == .pass)
        #expect(m.outcome?.details?["scene_depth_frames"] == "3")
    }
}
