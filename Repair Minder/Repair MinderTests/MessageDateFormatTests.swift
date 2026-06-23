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
    /// Regression: sortedMessages uses DateFormatters.parseDate which handles both
    /// space-format (workflow/SMS/automated notes) and ISO8601 timestamps.
    /// If parseDate parses a space-format timestamp as earlier than an ISO8601 one,
    /// the sort in sortedMessages will order them correctly.
    @Test func spaceFormatParsesEarlierThanISOWhenChronologicallyEarlier() {
        let spaceDate = DateFormatters.parseDate("2026-06-23 10:00:00")
        let isoDate = DateFormatters.parseDate("2026-06-23T11:00:00.000Z")
        #expect(spaceDate != nil)
        #expect(isoDate != nil)
        if let d1 = spaceDate, let d2 = isoDate {
            #expect(d1 < d2)
        }
    }
}
