// Features/Diagnostics/UI/SummaryView.swift
import SwiftUI

/// Results: overall grade, a Passed section, and a "Failed & Skipped – tap to retest"
/// section. Tapping a failed/skipped test reruns it (auto) or re-presents it (interactive).
struct SummaryView: View {
    @ObservedObject var runner: DiagnosticRunner
    @State private var showTransmit = false
    @State private var retestTest: RetestBox?

    /// Identifiable wrapper so we can drive a sheet with the chosen interactive test.
    struct RetestBox: Identifiable { let id: String; let test: any DiagnosticTest }

    var body: some View {
        List {
            Section("Result") {
                HStack {
                    Text("Overall")
                    Spacer()
                    Text(runner.overallResult.capitalized)
                        .fontWeight(.semibold)
                        .foregroundStyle(color(forResult: runner.overallResult))
                        .accessibilityIdentifier("summary-overall")
                }
            }

            if !runner.failedOrSkipped.isEmpty {
                Section("Failed & Skipped — tap any to retest") {
                    ForEach(runner.failedOrSkipped) { outcome in
                        row(outcome).contentShape(Rectangle())
                            .onTapGesture { retest(outcome) }
                            .accessibilityIdentifier("retest-\(outcome.id)")
                    }
                }
            }

            if !runner.passed.isEmpty {
                Section("Passed") {
                    ForEach(runner.passed) { outcome in row(outcome) }
                }
            }
        }
        .navigationTitle("Summary")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom) {
            Button {
                showTransmit = true
            } label: {
                Text("Send results")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .accessibilityIdentifier("send-results")
        }
        .navigationDestination(isPresented: $showTransmit) {
            TransmitView(runner: runner)
        }
        .sheet(item: $retestTest) { box in
            interactiveRetestSheet(box.test)
        }
    }

    @ViewBuilder
    private func row(_ outcome: TestOutcome) -> some View {
        HStack {
            Text(outcome.name)
            Spacer()
            Text(outcome.status.rawValue.capitalized)
                .foregroundStyle(color(forStatus: outcome.status))
        }
    }

    private func retest(_ outcome: TestOutcome) {
        guard let test = runner.tests.first(where: { $0.id == outcome.id }) else { return }
        if test.requiresInteraction {
            retestTest = RetestBox(id: test.id, test: test)
        } else {
            Task { await runner.retestAuto(test) }
        }
    }

    @ViewBuilder
    private func interactiveRetestSheet(_ test: any DiagnosticTest) -> some View {
        if let view = test.makeView(complete: { outcome in
            runner.record(outcome)
            retestTest = nil
        }) {
            view
        } else {
            Color.clear.onAppear { retestTest = nil }
        }
    }

    private func color(forResult result: String) -> Color {
        switch result {
        case "pass": return .green
        case "fail": return .red
        default: return .orange
        }
    }

    private func color(forStatus status: TestStatus) -> Color {
        switch status {
        case .pass: return .green
        case .fail: return .red
        case .skip: return .secondary
        case .partial, .error: return .orange
        }
    }
}
