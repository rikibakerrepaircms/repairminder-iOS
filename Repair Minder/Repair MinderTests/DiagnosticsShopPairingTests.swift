// Repair MinderTests/DiagnosticsShopPairingTests.swift
import Testing
@testable import Repair_Minder

struct DiagnosticsShopPairingTests {
    // One test method (not several) so the shared UserDefaults key isn't raced by parallel tests.
    @Test func pairingLifecycleAndValidation() {
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
    }
}
