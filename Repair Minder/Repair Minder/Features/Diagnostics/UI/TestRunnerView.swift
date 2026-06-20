// Features/Diagnostics/UI/TestRunnerView.swift
import SwiftUI

/// Runs the selected tests via the shared DiagnosticRunner, shows progress, then
/// hands off to the summary. Interactive per-test prompts (Pass/Fail) are added with
/// the hardware tests in a later task; auto tests (host-side) run without interaction.
struct TestRunnerView: View {
    @ObservedObject var runner: DiagnosticRunner
    @State private var started = false

    var body: some View {
        Group {
            if !started || runner.isRunning {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Running diagnostics…")
                        .font(.headline)
                        .accessibilityIdentifier("runner-running")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SummaryView(runner: runner)
            }
        }
        .navigationTitle("Diagnostics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard !started else { return }
            started = true
            await runner.runSelected()
        }
    }
}
