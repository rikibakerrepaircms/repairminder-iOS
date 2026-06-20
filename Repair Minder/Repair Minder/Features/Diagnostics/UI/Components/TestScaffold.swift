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
                VStack(alignment: .leading, spacing: 12) {
                    Text(instruction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(hints, id: \.self) { hint in
                        Label(hint, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    content()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding()
            }

            HStack(spacing: 12) {
                action("Skip", color: .gray, id: "test-skip", action: onSkip)
                action("Fail", color: .red, id: "test-fail", action: onFail)
                if allowManualPass {
                    action("Pass", color: .green, id: "test-pass", action: onPass)
                }
            }
            .padding()
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(Color.platformGroupedBackground)
    }

    private func action(_ label: String, color: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
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
