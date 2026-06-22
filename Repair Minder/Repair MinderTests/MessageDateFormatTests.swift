import Testing
import Foundation
@testable import Repair_Minder

struct MessageDateFormatTests {
    @Test func parsesSpaceFormatTimestamp() {
        #expect(DateFormatters.parseDate("2026-05-11 14:54:46") != nil)
    }
    @Test func parsesISO8601WithFraction() {
        #expect(DateFormatters.parseDate("2025-12-17T17:20:12.826Z") != nil)
    }
}
