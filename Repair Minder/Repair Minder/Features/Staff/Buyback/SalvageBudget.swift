import Foundation

/// Pure salvage-budget math + staging validity (mirrors web `computeSalvageBudget`
/// and the `canAdd` gate). `cap` = the device's purchase amount.
enum SalvageBudgetMath {
    static func round2(_ x: Double) -> Double { (x * 100).rounded() / 100 }

    static func remaining(cap: Double, booked: Double, pending: Double) -> Double {
        round2(cap - booked - pending)
    }

    /// Over budget when booked + pending exceeds the cap.
    static func overCap(cap: Double, booked: Double, pending: Double) -> Bool {
        round2(booked + pending) > round2(cap)
    }

    /// A group's category containing "screen" (case-insensitive) requires LCD/glass answers.
    static func isScreen(category: String?) -> Bool {
        (category ?? "").lowercased().contains("screen")
    }

    /// Can the currently-configured item be added to the batch?
    static func canAdd(groupId: String?, locationId: String?, isScreen: Bool, lcd: Int?, glass: Int?) -> Bool {
        guard let groupId, !groupId.isEmpty, let locationId, !locationId.isEmpty else { return false }
        if isScreen { return lcd != nil && glass != nil }
        return true
    }
}
