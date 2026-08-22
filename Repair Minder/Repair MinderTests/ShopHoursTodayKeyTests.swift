//
//  ShopHoursTodayKeyTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

/// Which day to MARK in the seven-row opening-hours list.
///
/// Seven rows only answer "are you open when I can get there?" if the reader can
/// find their own row. The row to mark is the SHOP's day, not the reader's - a
/// seller reading this in Sydney is already into tomorrow, and marking Tuesday while
/// Haverhill is still on Monday afternoon is the same class of mistake the status
/// panel exists to avoid.
///
/// Twin of `todayKey` in ShopVisitCard.tsx.
struct ShopHoursTodayKeyTests {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    @Test func namesTheShopsOwnDay() {
        // Saturday 22 August 2026, 11:00 UK (BST).
        #expect(ShopHours.todayKey(date("2026-08-22T10:00:00Z")) == "saturday")
    }

    /// 00:30 UK on the Sunday is already Sunday morning here and Sunday afternoon in
    /// Sydney - both agree - but 23:30 UK on the Saturday is Sunday in Sydney and
    /// still Saturday to us. The shop's clock decides.
    @Test func staysOnTheShopsDayWhenTheReaderIsAhead() {
        #expect(ShopHours.todayKey(date("2026-08-22T22:30:00Z")) == "saturday")
        #expect(ShopHours.todayKey(date("2026-08-22T23:30:00Z")) == "sunday")
    }

    @Test func coversEveryDayOfTheWeek() {
        // Mon 17 Aug 2026 through Sun 23 Aug 2026, midday UK each day.
        let expected = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for (offset, key) in expected.enumerated() {
            let day = 17 + offset
            #expect(ShopHours.todayKey(date(String(format: "2026-08-%02dT11:00:00Z", day))) == key)
        }
    }

    /// Every key it returns must exist in the display order, or the row it names can
    /// never be marked.
    @Test func alwaysNamesAKeyTheWeekListActuallyRenders() {
        let key = ShopHours.todayKey(date("2026-08-22T10:00:00Z"))
        #expect(key != nil)
        #expect(ShopHours.weekOrder.contains(key!))
    }
}
