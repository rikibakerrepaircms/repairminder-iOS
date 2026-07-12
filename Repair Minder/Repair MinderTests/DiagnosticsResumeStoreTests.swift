// Repair MinderTests/DiagnosticsResumeStoreTests.swift
import Testing
import Foundation
@testable import Repair_Minder

/// One test method (not several) so the shared UserDefaults keys aren't raced by parallel tests —
/// same convention as `DiagnosticsShopPairingTests`.
struct DiagnosticsResumeStoreTests {
    @Test func roundTripAndClear() {
        DiagnosticsResumeStore.clear()
        #expect(DiagnosticsResumeStore.load() == nil)

        DiagnosticsResumeStore.save(sessionId: "abc123", token: "tok456", reportID: "RM-0001")
        let loaded = DiagnosticsResumeStore.load()
        #expect(loaded?.sessionId == "abc123")
        #expect(loaded?.token == "tok456")
        #expect(loaded?.reportID == "RM-0001")

        // A save without a reportID clears any previously-stored one.
        DiagnosticsResumeStore.save(sessionId: "def789", token: "tok999", reportID: nil)
        let loadedNoReport = DiagnosticsResumeStore.load()
        #expect(loadedNoReport?.sessionId == "def789")
        #expect(loadedNoReport?.token == "tok999")
        #expect(loadedNoReport?.reportID == nil)

        // Blank id/token is refused (mirrors DiagnosticsShopPairing's validation-on-write pattern).
        DiagnosticsResumeStore.save(sessionId: "", token: "tok999", reportID: nil)
        #expect(DiagnosticsResumeStore.load()?.sessionId == "def789")   // unchanged

        DiagnosticsResumeStore.clear()
        #expect(DiagnosticsResumeStore.load() == nil)
    }
}
