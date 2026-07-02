import XCTest
@testable import Repair_Minder

@MainActor
final class PasscodeLockoutTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PasscodeService.shared.resetFailedAttempts()
    }
    override func tearDown() {
        PasscodeService.shared.resetFailedAttempts()
        super.tearDown()
    }

    func testBiometricBlockedAfterFiveFailures() {
        let service = PasscodeService.shared
        XCTAssertFalse(service.biometricBlocked)
        for _ in 0..<4 { service.recordFailedAttempt() }
        XCTAssertFalse(service.biometricBlocked, "4 failures must not block")
        service.recordFailedAttempt() // 5th
        XCTAssertTrue(service.biometricBlocked, "5th failure blocks biometrics")
    }

    func testResetClearsBlock() {
        let service = PasscodeService.shared
        for _ in 0..<5 { service.recordFailedAttempt() }
        XCTAssertTrue(service.biometricBlocked)
        service.resetFailedAttempts()
        XCTAssertFalse(service.biometricBlocked)
    }
}
