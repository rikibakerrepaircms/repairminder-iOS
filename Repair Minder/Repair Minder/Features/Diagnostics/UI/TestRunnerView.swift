// Features/Diagnostics/UI/TestRunnerView.swift
import SwiftUI

/// Drives a session: runs automatic tests in the background, then presents each interactive
/// test's view one at a time (each calls back with a Pass/Fail/Skip outcome), then the summary.
struct TestRunnerView: View {
    @ObservedObject var runner: DiagnosticRunner
    @State private var phase: Phase = .runningAuto
    @State private var interactiveIndex = 0

    enum Phase { case runningAuto, interactive, finished }

    var body: some View {
        Group {
            switch phase {
            case .runningAuto:
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Running automated checks…")
                        .font(.headline)
                        .accessibilityIdentifier("runner-running")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    if !runner.autoRan { await runner.runAuto() }
                    advance()
                }

            case .interactive:
                if let test = currentInteractive,
                   let view = test.makeView(complete: { outcome in
                       runner.record(outcome)
                       interactiveIndex += 1
                       advance()
                   }) {
                    view
                        .id(test.id)   // force a fresh view per interactive test
                } else {
                    Color.clear.onAppear { advance() }
                }

            case .finished:
                SummaryView(runner: runner)
            }
        }
        .navigationTitle("Diagnostics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var currentInteractive: DiagnosticTest? {
        let list = runner.selectedInteractiveTests
        return interactiveIndex < list.count ? list[interactiveIndex] : nil
    }

    private func advance() {
        phase = (currentInteractive == nil) ? .finished : .interactive
    }
}
