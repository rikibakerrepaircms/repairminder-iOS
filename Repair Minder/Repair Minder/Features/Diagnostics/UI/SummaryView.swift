// Features/Diagnostics/UI/SummaryView.swift
import SwiftUI

/// Results: colour-coded icon grid with failed tiles grouped at top.
/// Every tile is tappable to retest — pass, fail, or skip alike.
struct SummaryView: View {
    @ObservedObject var runner: DiagnosticRunner
    @State private var showTransmit = false
    @State private var retestTest: RetestBox?
    @State private var isGeneratingPDF = false

    /// Identifiable wrapper so we can drive a sheet with the chosen interactive test.
    struct RetestBox: Identifiable { let id: String; let test: any DiagnosticTest }

    // MARK: - Filtered outcome lists

    private var failedOutcomes: [TestOutcome] {
        runner.orderedOutcomes.filter { $0.status == .fail || $0.status == .error }
    }
    private var skippedOutcomes: [TestOutcome] {
        runner.orderedOutcomes.filter { $0.status == .skip }
    }
    private var passedOutcomes: [TestOutcome] {
        runner.orderedOutcomes.filter { $0.status == .pass }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card — grade + overall label + counts
                gradeHeaderCard

                // Failed / error section (red) — always first
                if !failedOutcomes.isEmpty {
                    gridSection(
                        title: "Failed",
                        titleColor: .red,
                        outcomes: failedOutcomes
                    )
                }

                // Skipped section (grey)
                if !skippedOutcomes.isEmpty {
                    gridSection(
                        title: "Skipped",
                        titleColor: .secondary,
                        outcomes: skippedOutcomes
                    )
                }

                // Passed section (green)
                if !passedOutcomes.isEmpty {
                    gridSection(
                        title: "Passed",
                        titleColor: .green,
                        outcomes: passedOutcomes
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: sharePDF) {
                    if isGeneratingPDF {
                        ProgressView()
                    } else {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isGeneratingPDF || runner.orderedOutcomes.isEmpty)
                .accessibilityIdentifier("share-pdf")
            }
        }
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
            GradeChip(grade: runner.grade)
                .scaleEffect(1.3)
                .padding(.top, 4)

            // XCUITest asserts: app.staticTexts["summary-overall"].label == "Pass"
            Text(runner.overallResult.capitalized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("summary-overall")

            HStack(spacing: 20) {
                statItem(count: passedOutcomes.count, label: "Passed", color: .green)
                statItem(count: failedOutcomes.count, label: "Failed", color: .red)
                statItem(count: skippedOutcomes.count, label: "Skipped", color: Color(.systemGray))
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

    // MARK: - Grid Section

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    @ViewBuilder
    private func gridSection(title: String, titleColor: Color, outcomes: [TestOutcome]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(titleColor)
                .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(outcomes) { outcome in
                    resultTile(outcome)
                }
            }
        }
    }

    // MARK: - Result Tile

    @ViewBuilder
    private func resultTile(_ outcome: TestOutcome) -> some View {
        let (tileColor, badgeIcon) = tileAppearance(for: outcome.status)

        Button {
            retest(outcome)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: DiagnosticIcons.symbol(for: outcome.id))
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(tileColor)

                        Image(systemName: badgeIcon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(tileColor)
                            .offset(x: 6, y: 6)
                    }
                    .padding(.top, 6)

                    Text(outcome.name)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
                .padding(.top, 14)

                // Retest affordance — small clockwise arrow in top-right corner
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tileColor.opacity(0.6))
                    .padding(6)
            }
            .frame(minHeight: 96)
            .background(tileColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tileColor.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("retest-\(outcome.id)")
    }

    /// Returns (tint colour, badge SF symbol) for a given status.
    private func tileAppearance(for status: TestStatus) -> (Color, String) {
        switch status {
        case .pass:           return (.green,  "checkmark.circle.fill")
        case .fail, .error:   return (.red,    "xmark.circle.fill")
        case .skip, .partial: return (Color(.systemGray), "minus.circle.fill")
        }
    }

    // MARK: - Share PDF

    #if os(iOS)
    /// Build the branded PDF report and present a share sheet (see DiagnosticReportShare).
    private func sharePDF() {
        guard !isGeneratingPDF else { return }
        isGeneratingPDF = true
        DiagnosticReportShare.presentShareSheet(for: runner) { _ in
            isGeneratingPDF = false
        }
    }
    #endif

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
