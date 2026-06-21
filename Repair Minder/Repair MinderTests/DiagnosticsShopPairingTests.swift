// Repair MinderTests/DiagnosticsShopPairingTests.swift
import Testing
import Foundation
@testable import Repair_Minder

struct DiagnosticsShopPairingTests {
    // One test method (not several) so the shared UserDefaults key isn't raced by parallel tests.
    @MainActor @Test func pairingLifecycleAndValidation() {
        DiagnosticsShopPairing.unpair()
        #expect(!DiagnosticsShopPairing.isPaired)
        #expect(DiagnosticsShopPairing.shopCode == nil)

        // Validation
        #expect(DiagnosticsShopPairing.isValidCode("123456"))
        #expect(!DiagnosticsShopPairing.isValidCode("12345"))    // too short
        #expect(!DiagnosticsShopPairing.isValidCode("1234567"))  // too long
        #expect(!DiagnosticsShopPairing.isValidCode("12345a"))   // non-numeric

        // Invalid codes don't pair
        DiagnosticsShopPairing.pair("12345")
        #expect(!DiagnosticsShopPairing.isPaired)
        DiagnosticsShopPairing.pair("abcdef")
        #expect(!DiagnosticsShopPairing.isPaired)

        // Valid code pairs + persists, then unpair clears it
        DiagnosticsShopPairing.pair("123456")
        #expect(DiagnosticsShopPairing.isPaired)
        #expect(DiagnosticsShopPairing.shopCode == "123456")
        DiagnosticsShopPairing.unpair()
        #expect(DiagnosticsShopPairing.shopCode == nil)

        // Company name (for "Welcome back …") — set with pairing, refreshed via setName, cleared on unpair.
        DiagnosticsShopPairing.pair("654321", name: "Mendmyi")
        #expect(DiagnosticsShopPairing.companyName == "Mendmyi")
        DiagnosticsShopPairing.setName("Mendmyi Ltd")
        #expect(DiagnosticsShopPairing.companyName == "Mendmyi Ltd")
        DiagnosticsShopPairing.pair("654321")   // re-pair without a name keeps the known one
        #expect(DiagnosticsShopPairing.companyName == "Mendmyi Ltd")
        DiagnosticsShopPairing.unpair()
        #expect(DiagnosticsShopPairing.companyName == nil)

        // Deep-link pairing intake (Bridge / QR / universal link can provision via a URL)
        #expect(DeepLinkHandler.shared.handleURL(URL(string: "repairminder://diagnostics/pair?shop=246802")!))
        #expect(DiagnosticsShopPairing.shopCode == "246802")
        DiagnosticsShopPairing.unpair()
        #expect(DeepLinkHandler.shared.handleURL(URL(string: "repairminder://pair?shop=357913")!))
        #expect(DiagnosticsShopPairing.shopCode == "357913")
        // Bad code is rejected
        DiagnosticsShopPairing.unpair()
        #expect(!DeepLinkHandler.shared.handleURL(URL(string: "repairminder://diagnostics/pair?shop=abc")!))
        #expect(!DiagnosticsShopPairing.isPaired)
        DiagnosticsShopPairing.unpair()
    }
}
