// Features/Diagnostics/UI/TestRunnerView.swift
import SwiftUI

/// Drives a session: runs automatic tests (shown as a live checklist), then presents each
/// interactive test one at a time, flashing a brief result confirmation between them, then the
/// summary. Phase/index live on the runner so backing out and re-entering resumes the session.
struct TestRunnerView: View {
    @ObservedObject var runner: DiagnosticRunner
    @Environment(\.dismiss) private var dismiss
    @State private var flash: TestOutcome?
    @State private var showStopConfirm = false

    var body: some View {
        Group {
            switch runner.phase {
            case .runningAuto:
                AutoRunChecklist(runner: runner) { advanceFromAuto() }

            case .interactive:
                if let flash {
                    ResultFlashView(outcome: flash)
                } else if let test = runner.currentInteractiveTest,
                          let view = test.makeView(complete: { handleOutcome($0) }) {
                    view.id(test.id)   // force a fresh view per interactive test
                } else {
                    Color.clear.onAppear { runner.phase = .finished }
                }

            case .finished:
                SummaryView(runner: runner)
            }
        }
        .navigationTitle("Diagnostics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(runner.phase != .finished)
        .toolbar {
            if runner.phase != .finished {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showStopConfirm = true } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityIdentifier("runner-back")
                }
            }
        }
        #endif
        .confirmationDialog("Stop diagnostics?", isPresented: $showStopConfirm, titleVisibility: .visible) {
            Button("Stop testing", role: .destructive) { dismiss() }
            Button("Continue testing", role: .cancel) {}
        } message: {
            Text("Your progress so far is kept — you can resume from where you left off.")
        }
    }

    /// Auto phase finished → move to the first interactive test, or straight to the summary.
    private func advanceFromAuto() {
        runner.phase = (runner.currentInteractiveTest == nil) ? .finished : .interactive
    }

    /// Record an interactive test's outcome, flash it briefly, then advance.
    private func handleOutcome(_ outcome: TestOutcome) {
        guard flash == nil else { return }   // ignore extra callbacks during the flash
        runner.record(outcome)
        flash = outcome
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            flash = nil
            runner.interactiveIndex += 1
            if runner.currentInteractiveTest == nil { runner.phase = .finished }
        }
    }
}

/// Runs the automatic tests once and lists each with a live ✓ / ✗ / skip status so passes are
/// visible rather than silent, then auto-advances.
private struct AutoRunChecklist: View {
    @ObservedObject var runner: DiagnosticRunner
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Automated checks")
                .font(.headline)
                .accessibilityIdentifier("runner-running")

            VStack(spacing: 10) {
                ForEach(runner.autoChecklistTests, id: \.id) { test in
                    HStack(spacing: 12) {
                        let outcome = runner.outcome(for: test.id)
                        Image(systemName: icon(for: outcome))
                            .foregroundStyle(color(for: outcome))
                            .frame(width: 24)
                        Text(test.name).font(.subheadline)
                        Spacer()
                        if outcome == nil { ProgressView().scaleEffect(0.8) }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if !runner.autoRan { await runner.runAuto() }
            // Brief beat so completed ticks are visible before the flow moves on.
            try? await Task.sleep(nanoseconds: 800_000_000)
            onDone()
        }
    }

    private func icon(for outcome: TestOutcome?) -> String {
        switch outcome?.status {
        case .pass: return "checkmark.circle.fill"
        case .fail, .error: return "xmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .skip: return "minus.circle.fill"
        case nil: return "circle"
        }
    }
    private func color(for outcome: TestOutcome?) -> Color {
        switch outcome?.status {
        case .pass: return .green
        case .fail, .error: return .red
        case .partial: return .orange
        case .skip: return .secondary
        case nil: return .secondary
        }
    }
}

/// Brief full-screen confirmation shown after an interactive test resolves, so a pass (or fail/skip)
/// is never silent.
private struct ResultFlashView: View {
    let outcome: TestOutcome

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(color)
            Text(label).font(.title2.bold())
            Text(outcome.name).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var icon: String {
        switch outcome.status {
        case .pass: return "checkmark.circle.fill"
        case .fail, .error: return "xmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .skip: return "minus.circle.fill"
        }
    }
    private var color: Color {
        switch outcome.status {
        case .pass: return .green
        case .fail, .error: return .red
        case .partial: return .orange
        case .skip: return .secondary
        }
    }
    private var label: String {
        switch outcome.status {
        case .pass: return "Passed"
        case .fail: return "Failed"
        case .error: return "Error"
        case .partial: return "Partial"
        case .skip: return "Skipped"
        }
    }
}
