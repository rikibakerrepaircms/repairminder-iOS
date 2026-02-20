import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension Color {
    // MARK: - Backgrounds

    static var platformBackground: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var platformGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.systemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    // MARK: - Grays

    static var platformGray4: Color {
        #if os(iOS)
        Color(UIColor.systemGray4)
        #elseif os(macOS)
        Color(nsColor: .systemGray)
        #endif
    }

    static var platformGray5: Color {
        #if os(iOS)
        Color(UIColor.systemGray5)
        #elseif os(macOS)
        Color(nsColor: .separatorColor)
        #endif
    }

    static var platformGray6: Color {
        #if os(iOS)
        Color(UIColor.systemGray6)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    // MARK: - Accent Colors

    static var platformBlue: Color {
        #if os(iOS)
        Color(UIColor.systemBlue)
        #elseif os(macOS)
        Color(nsColor: .controlAccentColor)
        #endif
    }
}
