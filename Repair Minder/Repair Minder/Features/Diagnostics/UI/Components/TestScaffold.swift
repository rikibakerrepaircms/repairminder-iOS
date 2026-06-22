// Features/Diagnostics/UI/Components/TestScaffold.swift
import SwiftUI

struct TestScaffold<Content: View>: View {
    let title: String
    let instruction: String
    var hints: [String] = []
    var allowManualPass: Bool = false
    /// true → content fills the entire screen edge-to-edge (touch grids, colour fills).
    /// false → content still fills the available vertical space, inside light padding.
    var fullBleed: Bool = false
    let onPass: () -> Void
    let onFail: () -> Void
    let onSkip: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Compact instruction header — does NOT steal the screen.
            VStack(alignment: .leading, spacing: 6) {
                Text(instruction).font(.subheadline).foregroundStyle(.secondary)
                if let hint = hints.first {
                    Label(hint, systemImage: "info.circle")
                        .font(.caption).foregroundStyle(Color.accentColor.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial)

            // Content fills ALL remaining space.
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(fullBleed ? 0 : 16)

            // Action bar — pinned, always visible. Glass cluster on iOS 26+ (blends as one).
            RMGlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    DiagnosticActionButton("Skip", color: .gray, id: "test-skip", action: onSkip)
                    DiagnosticActionButton("Fail", color: .red, id: "test-fail", action: onFail)
                    if allowManualPass {
                        DiagnosticActionButton("Pass", color: .green, id: "test-pass", action: onPass)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(Color(.systemGroupedBackground))
    }
}

/// The single, canonical full-width action button used for every test's Pass/Fail/Skip control,
/// so the controls look identical whether they live in TestScaffold's pinned bar or in a
/// custom full-bleed overlay (e.g. the touchscreen test).
struct DiagnosticActionButton: View {
    let label: String
    let color: Color
    let id: String
    let action: () -> Void

    init(_ label: String, color: Color, id: String, action: @escaping () -> Void) {
        self.label = label; self.color = color; self.id = id; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.rmGlassProminent(tint: color))
        .accessibilityIdentifier(id)
    }
}

/// Small helper to build a TestOutcome for a given test id/name + status.
func diagnosticOutcome(_ id: String, _ name: String, _ status: TestStatus,
                       _ details: [String: String]? = nil) -> TestOutcome {
    TestOutcome(id: id, name: name, status: status, details: details)
}
