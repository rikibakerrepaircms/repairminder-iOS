// Features/Diagnostics/UI/DiagnosticsFlowView.swift
import SwiftUI

/// Root coordinator for the no-login diagnostics flow. Hosts the test-selection →
/// wizard → summary → transmit screens (added in subsequent tasks). For now it
/// presents the entry root with a Close action back to role selection.
struct DiagnosticsFlowView: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                Text("Device Diagnostics")
                    .font(.largeTitle.bold())
                Text("Run a full hardware health check.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.platformGroupedBackground)
            .accessibilityIdentifier("diagnostics-root")
            .navigationTitle("Diagnostics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { appState.exitDiagnostics() }
                        .accessibilityIdentifier("diagnostics-close")
                }
            }
        }
    }
}

#Preview {
    DiagnosticsFlowView()
}
