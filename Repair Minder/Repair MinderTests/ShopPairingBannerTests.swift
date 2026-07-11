// Repair MinderTests/ShopPairingBannerTests.swift
import Testing
import Foundation
@testable import Repair_Minder

struct ShopPairingBannerTests {
    // One test method (not several) so the shared ShopPairingBanner.shared.message isn't raced
    // by parallel tests — mirrors DiagnosticsShopPairingTests' single-method convention.
    @MainActor @Test func showSetsConnectedCopyWithFallback() {
        let banner = ShopPairingBanner.shared

        banner.show(shopName: "Acme Repairs")
        #expect(banner.message == "Connected to Acme Repairs")

        // Empty / nil shop name falls back to a generic confirmation.
        banner.show(shopName: nil)
        #expect(banner.message == "Shop connected")
        banner.show(shopName: "")
        #expect(banner.message == "Shop connected")
    }
}
