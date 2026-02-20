//
//  PlatformCompatibility.swift
//  Repair Minder
//
//  macOS shims for iOS-only SwiftUI APIs so that shared view files compile
//  on both platforms without requiring #if os(iOS) at every call-site.
//

import SwiftUI

#if os(macOS)

// MARK: - NavigationBarTitleDisplayMode

/// Stub enum so `.navigationBarTitleDisplayMode(.inline)` compiles on macOS.
enum NavigationBarTitleDisplayMode {
    case inline, large, automatic
}

extension View {
    /// No-op on macOS — title display mode is not configurable.
    func navigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayMode) -> some View {
        self
    }
}

// MARK: - TextInputAutocapitalization

/// Stub enum so `.textInputAutocapitalization(.never)` compiles on macOS.
enum TextInputAutocapitalization {
    case never, words, sentences, characters
}

extension View {
    /// No-op on macOS — autocapitalisation is not configurable.
    func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization?) -> some View {
        self
    }
}

// MARK: - .listStyle(.insetGrouped) shim

extension View {
    /// Maps `.listStyle(.insetGrouped)` to the default macOS list style.
    func listStyle(_ style: _InsetGroupedShim) -> some View {
        self // use default list style on macOS
    }
}

enum _InsetGroupedShim {
    case insetGrouped
}

// MARK: - UIColor shim

/// Lightweight UIColor stand-in so `Color(.secondarySystemGroupedBackground)` compiles on macOS.
/// Maps UIKit semantic colors to their closest AppKit equivalents.
struct UIColor {
    let nsColor: NSColor
    static let secondarySystemGroupedBackground = UIColor(nsColor: .controlBackgroundColor)
    static let secondarySystemBackground = UIColor(nsColor: .controlBackgroundColor)
    static let tertiarySystemBackground = UIColor(nsColor: .underPageBackgroundColor)
    static let tertiarySystemFill = UIColor(nsColor: .quaternaryLabelColor)
    static let systemGroupedBackground = UIColor(nsColor: .windowBackgroundColor)
}

extension Color {
    /// Allows `Color(.secondarySystemGroupedBackground)` syntax on macOS.
    init(_ uiColor: UIColor) {
        self.init(nsColor: uiColor.nsColor)
    }
}

// MARK: - ToolbarItemPlacement shims

extension ToolbarItemPlacement {
    /// Maps `.topBarTrailing` to `.automatic` on macOS.
    static var topBarTrailing: ToolbarItemPlacement { .automatic }
    /// Maps `.topBarLeading` to `.automatic` on macOS.
    static var topBarLeading: ToolbarItemPlacement { .automatic }
    /// Maps `.navigationBarLeading` to `.navigation` on macOS.
    static var navigationBarLeading: ToolbarItemPlacement { .automatic }
    /// Maps `.navigationBarTrailing` to `.automatic` on macOS.
    static var navigationBarTrailing: ToolbarItemPlacement { .automatic }
}

// MARK: - SearchFieldPlacement shim

extension SearchFieldPlacement {
    /// Maps `.navigationBarDrawer(displayMode:)` to `.automatic` on macOS.
    static func navigationBarDrawer(displayMode: _DisplayMode = .automatic) -> SearchFieldPlacement {
        .automatic
    }
    enum _DisplayMode { case automatic, always }
}

// MARK: - UIKeyboardType shim

/// Stub so `keyboardType: .numberPad` compiles on macOS inside FormTextField.
enum UIKeyboardType: Int {
    case `default`, asciiCapable, numbersAndPunctuation, URL, numberPad
    case phonePad, namePhonePad, emailAddress, decimalPad, twitter
    case webSearch, asciiCapableNumberPad
}

extension View {
    /// No-op on macOS — keyboard type is not configurable.
    func keyboardType(_ type: UIKeyboardType) -> some View {
        self
    }
}

#endif
