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
        ScrollView {
            VStack(spacing: 20) {
                // Branded grade header card
                gradeHeaderCard

                // Failed & Skipped section
                if !runner.failedOrSkipped.isEmpty {
                    outcomeSection(
                        title: "Failed & Skipped",
                        subtitle: "Tap any row to retest",
                        outcomes: runner.failedOrSkipped,
                        isRetest: true
                    )
                }

                // Passed section
                if !runner.passed.isEmpty {
                    outcomeSection(
                        title: "Passed",
                        subtitle: nil,
                        outcomes: runner.passed,
                        isRetest: false
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
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
            .background(.ultraThinMaterial)
            .accessibilityIdentifier("send-results")
        }
        .navigationDestination(isPresented: $showTransmit) {
            TransmitView(runner: runner)
        }
        .sheet(item: $retestTest) { box in
            interactiveRetestSheet(box.test)
        }
    }

    // MARK: - Grade Header Card

    @ViewBuilder
    private var gradeHeaderCard: some View {
        VStack(spacing: 12) {
            // GradeChip displayed prominently
            GradeChip(grade: runner.grade)
                .scaleEffect(1.3)
                .padding(.top, 4)

            // summary-overall: staticText label must be the capitalised result word
            // XCUITest asserts: app.staticTexts["summary-overall"].label == "Pass"
            Text(runner.overallResult.capitalized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("summary-overall")

            // Stats row
            HStack(spacing: 24) {
                statItem(count: runner.passed.count, label: "Passed", color: .green)
                statItem(count: runner.failedOrSkipped.count, label: "Issues", color: .red)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func statItem(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2.weight(.bold))
                .foregroundStyle(count > 0 ? color : .secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Outcome Sections

    @ViewBuilder
    private func outcomeSection(title: String, subtitle: String?, outcomes: [TestOutcome], isRetest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text("— \(subtitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 4)

            // Rows card
            VStack(spacing: 0) {
                ForEach(Array(outcomes.enumerated()), id: \.element.id) { index, outcome in
                    outcomeRow(outcome, isRetest: isRetest)

                    if index < outcomes.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func outcomeRow(_ outcome: TestOutcome, isRetest: Bool) -> some View {
        Group {
            if isRetest {
                Button {
                    retest(outcome)
                } label: {
                    rowContent(outcome)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("retest-\(outcome.id)")
            } else {
                rowContent(outcome)
            }
        }
    }

    @ViewBuilder
    private func rowContent(_ outcome: TestOutcome) -> some View {
        HStack(spacing: 12) {
            Text(outcome.name)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            StatusPill(status: outcome.status)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Retest

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
}
