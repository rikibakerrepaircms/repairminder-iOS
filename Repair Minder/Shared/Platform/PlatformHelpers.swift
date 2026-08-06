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

/// Opens a Facebook Marketplace listing URL.
///
/// Previously wrapped the URL as `fb://facewebmodal/f?href=<url>` to hand off
/// to the native Facebook app. That only opens a generic in-app web-view tab,
/// not the native Marketplace item screen -- which is why it appeared to land
/// "somewhere generic" instead of the listing. Facebook does not expose a
/// documented (or discoverable) per-item Marketplace `fb://` scheme, and its
/// `apple-app-site-association` file explicitly excludes `/commerce/listing/*`
/// and `/commerce/products/*` from Universal Links with no `/marketplace/*`
/// entries at all, so there is no reliable native deep link to the item
/// screen. Opening the plain https URL lets the OS/browser (and, if present,
/// Facebook's own in-page "Open in app" banner) handle it instead.
func platformOpenMarketplaceListing(_ listingURL: URL) {
    platformOpenURL(listingURL)
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

/// Copy a string to the system clipboard
func platformCopyToClipboard(_ string: String) {
    #if os(iOS)
    UIPasteboard.general.string = string
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
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
