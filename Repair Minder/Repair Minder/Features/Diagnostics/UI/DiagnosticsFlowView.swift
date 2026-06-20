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
    }
}

#Preview {
    DiagnosticsFlowView()
}
