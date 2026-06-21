// Features/Diagnostics/UI/Components/TestScaffold.swift
import SwiftUI

/// Branded chrome shared by every interactive test: title + instruction + hints, the test's
/// custom interactive content, and a Pass / Fail / Skip action bar. RepairMinder styling.
/// Tests call the passed `onPass/onFail/onSkip` (or auto-complete from their content).
struct TestScaffold<Content: View>: View {
    let title: String
    let instruction: String
    var hints: [String] = []
    /// Automation-first: most tests auto-pass on a real signal, so the manual Pass button is
    /// hidden (only Fail/Skip remain as a fallback). Subjective tests (dead pixel, light) set true.
    var allowManualPass: Bool = false
    let onPass: () -> Void
    let onFail: () -> Void
    let onSkip: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Instruction card
                    VStack(alignment: .leading, spacing: 10) {
                        Text(instruction)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !hints.isEmpty {
                            Divider()
                            ForEach(hints, id: \.self) { hint in
                                Label(hint, systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor.opacity(0.8))
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)

                    // Test content slot
                    content()
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))

            // Action bar
            HStack(spacing: 12) {
                actionButton("Skip", color: .gray, id: "test-skip", action: onSkip)
                actionButton("Fail", color: .red, id: "test-fail", action: onFail)
                if allowManualPass {
                    actionButton("Pass", color: .green, id: "test-pass", action: onPass)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .background(Color(.systemGroupedBackground))
    }

    private func actionButton(_ label: String, color: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier(id)
    }
}

/// Small helper to build a TestOutcome for a given test id/name + status.
func diagnosticOutcome(_ id: String, _ name: String, _ status: TestStatus,
                       _ details: [String: String]? = nil) -> TestOutcome {
    TestOutcome(id: id, name: name, status: status, details: details)
}
