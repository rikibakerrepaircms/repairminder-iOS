//
//  BatteryHealth.swift
//  Repair Minder
//
//  The one place a battery health figure is turned into something to show.
//
//  Health is reported as (nominal charge capacity / DESIGN capacity), so a freshly
//  manufactured cell legitimately reads slightly over 100% — 102-103% is common on a
//  brand-new iPhone battery. The reading is valid, but "103% health" reads as a bug to
//  an operator, and iOS itself never shows above 100%. Clamp for DISPLAY only: the raw
//  value stays intact wherever it is stored.
//
//  IT TAKES A STRING, AND HAS TO. The API hands this figure over in three shapes:
//
//    - order_devices.battery_health_percent — a number on most rows, but TEXT like
//      "100%" on the 19 that came from M360, which reports it with the percent sign
//    - buyback_inventory.battery_health — TEXT holding a bare number, "100"
//    - DeviceDetail.batteryHealthPercent — a real Int
//
//  Before this existed there were two inline versions that disagreed: DeviceDetailView
//  clamped an Int with min(health, 100), and BuybackDetailView printed the raw string
//  unclamped and unsuffixed. The web had the same split until "100%" reached
//  Math.min and rendered a badge reading "NaN%" on order 100002885.
//
//  Web twin: src/utils/batteryHealth.ts. Change one, change both.
//

import Foundation
import SwiftUI

enum BatteryHealth {

    /// A health reading as a whole percentage, clamped to 0...100, or nil if there is
    /// nothing usable in it.
    ///
    /// Returning nil rather than a sentinel matters: every caller hides the badge on
    /// nil, so an unreadable value shows nothing instead of "NaN%" or "0%".
    static func display(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        // Strip the percent sign M360 includes, and any padding. A locale-independent
        // parse: this is a wire value, never something a user typed.
        let cleaned = raw.replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        return clamp(value)
    }

    /// The already-numeric case, so callers with an Int do not stringify it to get the
    /// same clamping.
    static func display(_ raw: Int?) -> Int? {
        guard let raw else { return nil }
        return clamp(Double(raw))
    }

    private static func clamp(_ value: Double) -> Int {
        Int(max(0, min(100, value.rounded())))
    }

    /// Green at 80 and above, amber from 60, red below — the bands the web dashboard
    /// uses on the same figure, so a device does not change colour between screens.
    static func tint(for percent: Int) -> Color {
        if percent >= 80 { return .green }
        if percent >= 60 { return .orange }
        return .red
    }
}
