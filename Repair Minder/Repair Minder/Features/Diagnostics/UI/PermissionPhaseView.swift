// Features/Diagnostics/UI/PermissionPhaseView.swift
import SwiftUI

/// First runner phase: request the union of permissions the selected tests need, up front. If any
/// required permission is denied, warn and offer Settings before continuing. Advances to `.preparing`.
struct PermissionPhaseView: View {
    @ObservedObject var runner: DiagnosticRunner

    var body: some View {
        #if os(iOS)
        PermissionPhaseBody(runner: runner)
        #else
        Color.clear.onAppear { runner.phase = .preparing }
        #endif
    }
}

#if os(iOS)
import UIKit

private struct PermissionPhaseBody: View {
    @ObservedObject var runner: DiagnosticRunner
    @StateObject private var coordinator = PermissionCoordinator()
    @State private var needed: Set<DiagnosticPermission> = []
    @State private var showDeniedWarning = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            if showDeniedWarning {
                Text("Some permissions were denied")
                    .font(.headline)
                Text("These tests need access to run and will be skipped or limited:\n\(deniedTestNames)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(.rmGlass())
                Button("Continue anyway") { runner.phase = .preparing }
                    .buttonStyle(.rmGlassProminent())
                    .accessibilityIdentifier("permissions-continue")
            } else {
                Text("Setting up")
                    .font(.headline)
                    .accessibilityIdentifier("permissions-running")
                Text(coordinator.inFlight.map { "Requesting \(label(for: $0)) access…" } ?? "Preparing permissions…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            needed = requiredPermissionsUnion(for: runner.selectedTests)
            guard !needed.isEmpty else { runner.phase = .preparing; return }
            await coordinator.request(needed)
            // Record the granted map on the runner BEFORE any transition to .preparing so preflight
            // (which runs in the preparing phase) can skip probes for denied permissions. Covers both
            // the no-denied path below and the "Continue anyway" button (which also goes to .preparing).
            runner.grantedPermissions = coordinator.granted
            let anyDenied = needed.contains { coordinator.granted[$0] == false }
            if anyDenied { showDeniedWarning = true } else { runner.phase = .preparing }
        }
    }

    private var deniedTestNames: String {
        let deniedPerms = needed.filter { coordinator.granted[$0] == false }
        let names = runner.selectedTests
            .filter { !Set($0.requiredPermissions).isDisjoint(with: deniedPerms) }
            .map(\.name)
        return names.isEmpty ? "—" : names.joined(separator: ", ")
    }

    private func label(for p: DiagnosticPermission) -> String {
        switch p {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .location: return "Location"
        case .bluetooth: return "Bluetooth"
        }
    }
}
#endif
