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

            // Action bar — pinned, always visible.
            HStack(spacing: 12) {
                actionButton("Skip", color: .gray, id: "test-skip", action: onSkip)
                actionButton("Fail", color: .red, id: "test-fail", action: onFail)
                if allowManualPass {
                    actionButton("Pass", color: .green, id: "test-pass", action: onPass)
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

    private func actionButton(_ label: String, color: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(color).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier(id)
    }
}

/// Small helper to build a TestOutcome for a given test id/name + status.
func diagnosticOutcome(_ id: String, _ name: String, _ status: TestStatus,
                       _ details: [String: String]? = nil) -> TestOutcome {
    TestOutcome(id: id, name: name, status: status, details: details)
}
