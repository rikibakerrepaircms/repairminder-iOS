// Features/Diagnostics/UI/DiagnosticsFlowView.swift
import SwiftUI

/// Root coordinator for the no-login diagnostics flow. Hosts the test-selection →
/// wizard → summary → transmit screens (added in subsequent tasks). For now it
/// presents the entry root with a Close action back to role selection.
struct DiagnosticsFlowView: View {
    var body: some View {
        NavigationStack {
            TestSelectionView()
        }
        // Transient "Connected to <shop>" confirmation, driven by ShopPairingBanner.shared and
        // fired when the Bridge USB handshake pairs this device. Mounted here (the diagnostics
        // root) as a top overlay so it appears regardless of which screen is on top.
        .overlay(alignment: .top) { ShopConnectedBanner() }
        // Best-effort, non-blocking: replay any sessions buffered offline so they complete
        // (create → results → complete) instead of stranding `in_progress`. The flow opening
        // means we likely have network now.
        .task { await DiagnosticsService().flushPending() }
    }
}

#Preview {
    DiagnosticsFlowView()
}
