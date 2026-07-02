//
//  PasscodeColdLaunchLockTests.swift
//  Repair MinderTests
//
//  Tests that the app locks on cold launch from authoritative state, not just the local hash cache.
//

import XCTest
@testable import Repair_Minder

@MainActor
final class PasscodeColdLaunchLockTests: XCTestCase {
    private let kc = KeychainManager.shared

    override func tearDown() {
        kc.clearPasscodeData()
        kc.clearStaffTokens()
        PasscodeService.shared.unlockApp()
        super.tearDown()
    }

    /// Reproduces the bug: passcode enabled + "On App Close" + a valid session, but NO
    /// locally cached hash (e.g. reinstalled build / passcode set on another device).
    /// The app MUST still lock on cold launch — it must not trust only the local hash.
    func testColdLaunchLocksWhenEnabledEvenWithoutCachedHash() {
        kc.clearPasscodeData()            // ensure no cached hash/salt/enabled
        kc.setAccessToken("test-session-token")
        kc.setPasscodeEnabled(true)
        kc.setPasscodeTimeout(0)          // On App Close

        let svc = PasscodeService.shared
        svc.unlockApp()                   // reset any prior state
        svc.loadLocalState()

        XCTAssertTrue(svc.isLocked,
            "On App Close + enabled passcode + session must lock on cold launch even without a locally cached hash")
    }

    /// Sanity: with no session (logged out), it must NOT lock even if stale passcode flags linger.
    func testNoLockWhenNoSession() {
        kc.clearPasscodeData()
        kc.clearStaffTokens()             // no access token
        kc.setPasscodeEnabled(true)
        kc.setPasscodeTimeout(0)

        let svc = PasscodeService.shared
        svc.unlockApp()
        svc.loadLocalState()

        XCTAssertFalse(svc.isLocked, "A logged-out app must never lock")
    }
}
