import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Open a URL using the platform's native mechanism
func platformOpenURL(_ url: URL) {
    #if os(iOS)
    UIApplication.shared.open(url)
    #elseif os(macOS)
    NSWorkspace.shared.open(url)
    #endif
}

/// Open system settings/preferences
func platformOpenSystemSettings() {
    #if os(iOS)
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
    #elseif os(macOS)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
        NSWorkspace.shared.open(url)
    }
    #endif
}

/// Register for remote (push) notifications
func platformRegisterForRemoteNotifications() {
    #if os(iOS)
    UIApplication.shared.registerForRemoteNotifications()
    #elseif os(macOS)
    NSApplication.shared.registerForRemoteNotifications()
    #endif
}

/// Get device model name for push token registration
func platformDeviceModel() -> String {
    #if os(iOS)
    return UIDevice.current.model
    #elseif os(macOS)
    return "Mac"
    #endif
}

/// Get OS version string for push token registration
func platformOSVersion() -> String {
    #if os(iOS)
    return UIDevice.current.systemVersion
    #elseif os(macOS)
    let v = ProcessInfo.processInfo.operatingSystemVersion
    return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    #endif
}

/// Platform identifier string for API registration
var platformIdentifier: String {
    #if os(iOS)
    return "ios"
    #elseif os(macOS)
    return "macos"
    #endif
}
