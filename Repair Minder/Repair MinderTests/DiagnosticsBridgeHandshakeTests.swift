// Repair MinderTests/DiagnosticsBridgeHandshakeTests.swift
import Testing
import Foundation
@testable import Repair_Minder

#if os(iOS)
@MainActor
struct DiagnosticsBridgeHandshakeTests {
    // One test method (not several) so the shared DiagnosticsShopPairing UserDefaults
    // state and the ShopPairingBanner.shared singleton aren't raced by parallel tests —
    // mirrors DiagnosticsShopPairingTests' / ShopPairingBannerTests' convention.
    @Test func applyRePairsOnDifferentTokenNoOpsOnIdentical() {
        DiagnosticsShopPairing.unpair()
        ShopPairingBanner.shared.show(shopName: nil)

        // First handshake pairs and shows the banner.
        DiagnosticsBridgeHandshake.shared.apply(token: "tok-A", name: "Acme")
        #expect(DiagnosticsShopPairing.token == "tok-A")
        #expect(ShopPairingBanner.shared.message == "Connected to Acme")

        // Reset the banner so the next assertion observes a genuinely NEW change.
        ShopPairingBanner.shared.show(shopName: nil)
        #expect(ShopPairingBanner.shared.message == "Shop connected")

        // The SAME bench handshakes again (identical token) -> no-op: token
        // unchanged, banner NOT re-shown (still whatever we just reset it to).
        DiagnosticsBridgeHandshake.shared.apply(token: "tok-A", name: "Acme")
        #expect(DiagnosticsShopPairing.token == "tok-A")
        #expect(ShopPairingBanner.shared.message == "Shop connected")

        // A DIFFERENT bench's token arrives (e.g. this device inherited another
        // device's token via a backup/restore and is now on ITS OWN bench) ->
        // re-pairs and re-shows the banner with the new shop's name
        // (latest-handshake-wins, B1).
        DiagnosticsBridgeHandshake.shared.apply(token: "tok-B", name: "Beta Repairs")
        #expect(DiagnosticsShopPairing.token == "tok-B")
        #expect(ShopPairingBanner.shared.message == "Connected to Beta Repairs")

        DiagnosticsShopPairing.unpair()
    }
}
#endif
