//
//  BatteryHealthTests.swift
//  Repair MinderTests
//
//  The API hands this figure over in three shapes - "100%" from M360 on order devices,
//  a bare "100" on buyback inventory, and a real Int on DeviceDetail - and the app used
//  to have two inline versions of the rule that disagreed with each other. The web had
//  the same split until "100%" reached Math.min and rendered "NaN%" on order 100002885.
//

import Testing
@testable import Repair_Minder

struct BatteryHealthTests {

    @Test func readsThePercentSignM360Sends() {
        #expect(BatteryHealth.display("100%") == 100)
        #expect(BatteryHealth.display("82%") == 82)
    }

    @Test func readsTheBareNumberBuybackInventoryStores() {
        #expect(BatteryHealth.display("100") == 100)
        #expect(BatteryHealth.display("89") == 89)
    }

    /// A new cell genuinely reads 102-103% against DESIGN capacity. Valid, but it looks
    /// like a bug, and iOS itself never shows above 100.
    @Test func clampsAnOverfullCell() {
        #expect(BatteryHealth.display("103%") == 100)
        #expect(BatteryHealth.display(103) == 100)
    }

    @Test func clampsTheIntPathIdentically() {
        #expect(BatteryHealth.display(88) == 88)
        #expect(BatteryHealth.display(-5) == 0)
    }

    /// Every caller hides the badge on nil, so an unreadable value must show NOTHING
    /// rather than "NaN%" or a misleading "0%".
    @Test func returnsNilForAnythingUnusable() {
        #expect(BatteryHealth.display(nil as String?) == nil)
        #expect(BatteryHealth.display("") == nil)
        #expect(BatteryHealth.display("%") == nil)
        #expect(BatteryHealth.display("unknown") == nil)
        #expect(BatteryHealth.display("  ") == nil)
    }

    @Test func handlesPaddingAroundTheValue() {
        #expect(BatteryHealth.display(" 88% ") == 88)
    }

    /// The bands must match the web row and the device card, so a handset does not
    /// change colour between screens.
    @Test func bandsMatchTheWebDashboard() {
        #expect(BatteryHealth.tint(for: 80) == .green)
        #expect(BatteryHealth.tint(for: 79) == .orange)
        #expect(BatteryHealth.tint(for: 60) == .orange)
        #expect(BatteryHealth.tint(for: 59) == .red)
    }
}
