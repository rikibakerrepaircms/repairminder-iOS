import Testing
@testable import Repair_Minder

@MainActor final class FakeQR: QRProbe {
    func start(onCode: @escaping (String) -> Void) { onCode("test-code") }
    func stop() {}
}
struct FrontCameraViewModelTests {
    @Test @MainActor func passesOnQR() {
        let m = FrontCameraViewModel(probe: FakeQR())
        m.start()
        #expect(m.outcome?.status == .pass)
        #expect(m.outcome?.details?["qr_detected"] == "1")
    }
}
