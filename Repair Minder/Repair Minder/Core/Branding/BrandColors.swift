//
//  BrandColors.swift
//  Repair Minder
//
//  Dynamic color palette for white-label branding
//

import SwiftUI

struct BrandColors: Sendable {
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surface: Color
    let error: Color
    let success: Color
    let warning: Color

    // MARK: - Brand Presets

    static let repairMinder = BrandColors(
        primary: Color(hex: 0x007AFF),        // iOS Blue
        secondary: Color(hex: 0x5856D6),      // Purple
        accent: Color(hex: 0xFF9500),         // Orange
        background: Color(.systemBackground),
        surface: Color(.secondarySystemBackground),
        error: Color(hex: 0xFF3B30),          // Red
        success: Color(hex: 0x34C759),        // Green
        warning: Color(hex: 0xFF9500)         // Orange
    )

    static let clientA = BrandColors(
        primary: Color(hex: 0x34C759),        // Green
        secondary: Color(hex: 0x30D158),      // Bright Green
        accent: Color(hex: 0x007AFF),         // Blue
        background: Color(.systemBackground),
        surface: Color(.secondarySystemBackground),
        error: Color(hex: 0xFF3B30),
        success: Color(hex: 0x34C759),
        warning: Color(hex: 0xFF9500)
    )
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Environment Key

struct BrandColorsKey: EnvironmentKey {
    static let defaultValue = BrandColors.repairMinder
}

extension EnvironmentValues {
    var brandColors: BrandColors {
        get { self[BrandColorsKey.self] }
        set { self[BrandColorsKey.self] = newValue }
    }
}
