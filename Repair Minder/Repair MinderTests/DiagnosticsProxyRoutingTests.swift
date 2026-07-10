// Repair MinderTests/DiagnosticsProxyRoutingTests.swift
import Testing
import Foundation
@testable import Repair_Minder

/// Bridge secrecy Layer 1: the 3 diagnostics session endpoints route through the masked
/// `api.kimrelay.com` proxy (`/w/<path>`, leading `/api/` stripped) instead of hitting
/// `api.repairminder.com` directly. Everything else is unaffected.
struct DiagnosticsProxyRoutingTests {
    @Test func diagnosticsEndpointsAreProxyRouted() {
        #expect(APIEndpoint.diagnosticsPublicCreate.isDiagnosticsProxyRouted)
        #expect(APIEndpoint.diagnosticsSubmitResult.isDiagnosticsProxyRouted)
        #expect(APIEndpoint.diagnosticsComplete(sessionId: "abc123").isDiagnosticsProxyRouted)
    }

    @Test func unrelatedEndpointsAreNotProxyRouted() {
        #expect(!APIEndpoint.login.isDiagnosticsProxyRouted)
        #expect(!APIEndpoint.dashboardStats(scope: nil, period: nil).isDiagnosticsProxyRouted)
    }

    @Test func resolvesPublicCreateToProxyHostWithApiPrefixStripped() {
        let url = DiagnosticsProxyURL.resolve(
            path: APIEndpoint.diagnosticsPublicCreate.path,
            proxyBase: URL(string: "https://api.kimrelay.com")!)
        #expect(url.absoluteString == "https://api.kimrelay.com/w/public/diagnostics/session")
    }

    @Test func resolvesCompleteWithSessionIdToProxyHost() {
        let url = DiagnosticsProxyURL.resolve(
            path: APIEndpoint.diagnosticsComplete(sessionId: "abc123").path,
            proxyBase: URL(string: "https://api.kimrelay.com")!)
        #expect(url.absoluteString == "https://api.kimrelay.com/w/diagnostics/session/abc123/complete")
    }

    @Test func resolvesSubmitResultToProxyHost() {
        let url = DiagnosticsProxyURL.resolve(
            path: APIEndpoint.diagnosticsSubmitResult.path,
            proxyBase: URL(string: "https://api.kimrelay.com")!)
        #expect(url.absoluteString == "https://api.kimrelay.com/w/diagnostics/results")
    }
}
