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
            case .permissions:
                PermissionPhaseView(runner: runner)

            case .preparing:
                PreparingView(runner: runner) { advanceFromPreparing() }

            case .interactive:
                if let flash {
                    ResultFlashView(outcome: flash)
                        .task(id: flash.id) {
                            try? await Task.sleep(nanoseconds: 1_100_000_000)
                            guard !Task.isCancelled else { return }
                            self.flash = nil
                            runner.interactiveIndex += 1
                            if runner.currentInteractiveTest == nil { runner.phase = .finished }
                        }
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

    /// Preparing finished → move to the first remaining interactive test, or straight to summary.
    private func advanceFromPreparing() {
        runner.phase = (runner.currentInteractiveTest == nil) ? .finished : .interactive
    }

    /// Record an interactive test's outcome and flash it; the flash view owns the advance timer
    /// (bound to its lifetime so backing out cancels it cleanly).
    private func handleOutcome(_ outcome: TestOutcome) {
        guard flash == nil else { return }   // ignore extra callbacks during the flash
        runner.record(outcome)
        flash = outcome
    }
}

/// Runs the automatic tests + background pre-flight, showing a live checklist and a 1–2s banner per
/// background pass, then auto-advances. Re-entry-safe (guards on `autoRan` / `preflightRan`).
private struct PreparingView: View {
    @ObservedObject var runner: DiagnosticRunner
    let onDone: () -> Void
    @State private var banner: TestOutcome?

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 16) {
                Text("Preparing…")
                    .font(.headline)
                    .accessibilityIdentifier("runner-running")   // keep stable id so existing UITests still match

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

            if let banner {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("\(banner.name) passed").font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .rmGlassCapsule()
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier("preflight-banner")
            }
        }
        .task {
            if !runner.autoRan { await runner.runAuto() }
            await runner.runPreflight()
            // Brief beat so completed ticks are visible.
            try? await Task.sleep(nanoseconds: 400_000_000)
            // Play a 1.5s banner per background pass.
            for outcome in runner.backgroundPassed {
                withAnimation { banner = outcome }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation { banner = nil }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
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
        .padding(32)
        .rmGlassCardBackground(cornerRadius: 24, fallbackFill: Color(.secondarySystemGroupedBackground))
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
