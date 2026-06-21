// Features/Diagnostics/Transport/DiagnosticsShopPairing.swift
import Foundation

/// Persists the shop a device is "paired" to. A **paired** device (a shop's own test device)
/// auto-sends each diagnostic run to that shop on finish; an **unpaired** (consumer App Store)
/// device only transmits when a shop code is entered manually — nothing is recorded otherwise.
///
/// The 6-digit shop code is not sensitive (it only routes results to a company that already chose
/// to expose it), so UserDefaults is sufficient. Pairing is set when the user ticks
/// "Remember this shop on this device" on the Send-Results screen; later the in-shop Bridge install
/// path can seed it automatically (see docs/plans/device-diagnostics/31-...).
enum DiagnosticsShopPairing {
    private static let key = "diagnostics.pairedShopCode"
    private static let nameKey = "diagnostics.pairedShopName"
    private static var store: UserDefaults { .standard }

    static func isValidCode(_ code: String) -> Bool {
        code.count == 6 && code.allSatisfy(\.isNumber)
    }

    /// The paired shop code, or nil if this device isn't paired to a shop.
    static var shopCode: String? {
        guard let c = store.string(forKey: key), isValidCode(c) else { return nil }
        return c
    }
    /// The paired shop's company name (for "Welcome back …"), if known.
    static var companyName: String? {
        guard isPaired, let n = store.string(forKey: nameKey), !n.isEmpty else { return nil }
        return n
    }
    static var isPaired: Bool { shopCode != nil }

    /// Pair to a shop. A nil/empty `name` leaves any previously-known name intact (e.g. a
    /// deep-link without a name, or a transmit that didn't return one).
    static func pair(_ code: String, name: String? = nil) {
        guard isValidCode(code) else { return }
        store.set(code, forKey: key)
        if let name, !name.isEmpty { store.set(name, forKey: nameKey) }
    }

    /// Refresh the paired shop's name (no-op if unpaired or name empty).
    static func setName(_ name: String?) {
        guard isPaired, let name, !name.isEmpty else { return }
        store.set(name, forKey: nameKey)
    }

    static func unpair() {
        store.removeObject(forKey: key)
        store.removeObject(forKey: nameKey)
    }
}
