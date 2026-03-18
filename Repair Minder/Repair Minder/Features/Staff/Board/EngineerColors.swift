//
//  EngineerColors.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//
//  Deterministic colour assignment matching the web implementation exactly.
//  Uses the same 12-colour palette and hash algorithm as engineerColors.ts.
//  Supports user overrides stored in UserDefaults (synced with web localStorage).
//

import SwiftUI

// MARK: - Engineer Colors

enum EngineerColors {

    /// 12-colour palette matching web EXACTLY (same order as engineerColors.ts)
    static let palette: [(bg: String, ring: String)] = [
        ("#3B82F6", "#93BBFD"),  // blue
        ("#10B981", "#6EE7B7"),  // emerald
        ("#F59E0B", "#FCD34D"),  // amber
        ("#EF4444", "#FCA5A5"),  // red
        ("#8B5CF6", "#C4B5FD"),  // violet
        ("#EC4899", "#F9A8D4"),  // pink
        ("#14B8A6", "#5EEAD4"),  // teal
        ("#F97316", "#FDBA74"),  // orange
        ("#6366F1", "#A5B4FC"),  // indigo
        ("#06B6D4", "#67E8F9"),  // cyan
        ("#84CC16", "#BEF264"),  // lime
        ("#D946EF", "#E879F9"),  // fuchsia
    ]

    private static let overridesKey = "board-engineer-colors"

    /// Hash function matching JavaScript's `((hash << 5) - hash + charCode) | 0`
    /// Uses Int32 overflow arithmetic to match JS's `| 0` (32-bit truncation)
    private static func hashString(_ str: String) -> Int {
        var hash: Int32 = 0
        for byte in str.utf8 {
            hash = ((hash &<< 5) &- hash) &+ Int32(byte)
        }
        return Int(abs(hash))
    }

    /// Get saved overrides from UserDefaults
    private static func getOverrides() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: overridesKey) as? [String: Int] ?? [:]
    }

    /// Resolve palette index for an engineer (override or hash fallback)
    private static func paletteIndex(for engineerId: String) -> Int {
        let overrides = getOverrides()
        if let idx = overrides[engineerId], idx >= 0, idx < palette.count {
            return idx
        }
        return hashString(engineerId) % palette.count
    }

    /// Get the background Color for an engineer ID
    static func color(for engineerId: String) -> Color {
        Color(hex: palette[paletteIndex(for: engineerId)].bg)
    }

    /// Get the ring Color for an engineer ID
    static func ringColor(for engineerId: String) -> Color {
        Color(hex: palette[paletteIndex(for: engineerId)].ring)
    }

    /// Get the hex string pair for an engineer ID
    static func hexColors(for engineerId: String) -> (bg: String, ring: String) {
        palette[paletteIndex(for: engineerId)]
    }

    /// Save a colour override for an engineer
    static func setOverride(for engineerId: String, paletteIndex: Int) {
        var overrides = getOverrides()
        overrides[engineerId] = paletteIndex
        UserDefaults.standard.set(overrides, forKey: overridesKey)
    }

    /// Remove a colour override (revert to hash-based)
    static func clearOverride(for engineerId: String) {
        var overrides = getOverrides()
        overrides.removeValue(forKey: engineerId)
        UserDefaults.standard.set(overrides, forKey: overridesKey)
    }
}
