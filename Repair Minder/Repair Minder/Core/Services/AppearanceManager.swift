//
//  AppearanceManager.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @AppStorage("appearanceMode") var mode: String = AppearanceMode.system.rawValue

    var currentMode: AppearanceMode {
        get { AppearanceMode(rawValue: mode) ?? .system }
        set { mode = newValue.rawValue }
    }

    var preferredColorScheme: ColorScheme? {
        currentMode.colorScheme
    }
}
