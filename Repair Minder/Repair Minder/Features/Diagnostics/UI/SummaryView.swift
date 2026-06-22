// Features/Diagnostics/UI/SummaryView.swift
import SwiftUI

/// Pure visual + textual mapping for a result tile, factored out so it can be unit-tested.
/// `.partial` is now distinct from `.skip` (orange "exclamationmark" + the word "Partial")
/// instead of both rendering as grey "minus".
struct ResultTileAppearance: Equatable {
    let color: Color
    let icon: String
    /// Human/VoiceOver status word.
    let statusWord: String
}

enum ResultTilePresentation {
    static func appearance(for status: TestStatus) -> ResultTileAppearance {
        switch status {
        case .pass:    return ResultTileAppearance(color: .green,  icon: "checkmark.circle.fill", statusWord: "Passed")
        case .fail:    return ResultTileAppearance(color: .red,    icon: "xmark.circle.fill",     statusWord: "Failed")
        case .error:   return ResultTileAppearance(color: .red,    icon: "xmark.circle.fill",     statusWord: "Error")
        case .partial: return ResultTileAppearance(color: .orange, icon: "exclamationmark.circle.fill", statusWord: "Partial")
        case .skip:    return ResultTileAppearance(color: Color(.systemGray), icon: "minus.circle.fill", statusWord: "Skipped")
        }
    }

    /// VoiceOver label for a result tile: "<name>: <status>".
    static func accessibilityLabel(name: String, status: TestStatus) -> String {
        "\(name): \(appearance(for: status).statusWord)"
    }
}

/// Results: colour-coded icon grid with failed tiles grouped at top.
/// Every tile is tappable to retest — pass, fail, or skip alike.
struct SummaryView: View {
    @ObservedObject var runner: DiagnosticRunner
    @State private var showTransmit = false
    @State private var retestTest: RetestBox?
    @State private var isGeneratingPDF = false
    @State private var autoSend: AutoSend = .idle
    @Namespace private var resultGlass

    /// Auto-send state for a shop-paired device (idle until the run is sent on appear / retest).
    enum AutoSend: Equatable { case idle, sending, sent, failed, unlinked }

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
            RMGlassEffectContainer(spacing: 12) {
                VStack(spacing: 20) {
                    // Header card — grade + overall label + counts
                    gradeHeaderCard

                    // On-device PDF preview row (same report as the top-right Share arrow)
                    #if os(iOS)
                    generatePDFRow
                    #endif

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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .rmSoftTopScrollEdge()
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
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onAppear { autoSendIfPaired() }
        .navigationDestination(isPresented: $showTransmit) {
            TransmitView(runner: runner)
        }
        .sheet(item: $retestTest) { box in
            interactiveRetestSheet(box.test)
        }
    }

    // MARK: - Bottom bar (auto-send when paired, manual otherwise)

    @ViewBuilder
    private var bottomBar: some View {
        if DiagnosticsShopPairing.isPaired {
            Button { showTransmit = true } label: {
                autoSendLabel
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(autoSendColor)
                    .rmGlassTintedCard(cornerRadius: 12,
                                       tint: autoSendColor.opacity(0.3),
                                       fallbackFill: autoSendColor.opacity(0.15))
            }
            .padding()
            .background(.ultraThinMaterial)
            .accessibilityIdentifier("auto-send-status")
        } else {
            Button { showTransmit = true } label: {
                Text("Send results")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.rmGlassProminent())
            .padding()
            .background(.ultraThinMaterial)
            .accessibilityIdentifier("send-results")
        }
    }

    private var autoSendColor: Color {
        switch autoSend {
        case .sent: return .green
        case .failed, .unlinked: return .orange
        default: return .accentColor
        }
    }

    @ViewBuilder
    private var autoSendLabel: some View {
        switch autoSend {
        case .idle, .sending:
            HStack(spacing: 8) { ProgressView(); Text("Sending to your shop…") }
        case .sent:
            Label("Sent to your shop", systemImage: "checkmark.circle.fill")
        case .failed:
            Label("Saved on device — will sync when connected", systemImage: "exclamationmark.triangle.fill")
        case .unlinked:
            Label("This device is no longer linked to a shop", systemImage: "link.badge.minus")
        }
    }

    // MARK: - Auto-send (shop-paired devices)

    private var deviceDescription: String? {
        let os = runner.outcome(for: "device_info")?.details?["os_version"]
        let parts = [DeviceModelName.marketingName, os].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func makeService() -> DiagnosticsService {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestStubTransmit") {
            return DiagnosticsService(api: StubDiagnosticsAPI())
        }
        #endif
        return DiagnosticsService()
    }

    /// On a shop-paired device, send (or re-send) the run to the paired shop. Safe to call
    /// repeatedly — the Worker reuses one session per run (report_id) and upserts each test.
    private func autoSendIfPaired() {
        guard DiagnosticsShopPairing.isPaired, !runner.orderedOutcomes.isEmpty else { return }
        autoSend = .sending
        let service = makeService()
        let outcomes = runner.orderedOutcomes
        let reportID = runner.reportID
        let overall = runner.overallResult
        let desc = deviceDescription
        let code = DiagnosticsShopPairing.shopCode       // one of these is set (token preferred)
        let token = DiagnosticsShopPairing.token
        Task {
            do {
                let companyName = try await service.transmit(
                    shopCode: code, pairingToken: token, platform: "ios", imei: nil, serial: nil,
                    deviceDescription: desc, reportID: reportID, overallResult: overall, outcomes: outcomes)
                DiagnosticsShopPairing.setName(companyName)   // refresh "Welcome back …" name from server
                autoSend = .sent
            } catch {
                switch DiagnosticsTransmitOutcome.classify(error, wasTokenPairing: token != nil) {
                case .revokedPairing:
                    DiagnosticsShopPairing.unpair()   // device no longer linked — stop auto-sending
                    autoSend = .unlinked
                case .transient:
                    DiagnosticsBuffer.save(shopCode: code, pairingToken: token, deviceDescription: desc,
                                           imei: nil, serial: nil, reportID: reportID,
                                           overallResult: overall, outcomes: outcomes)
                    autoSend = .failed
                }
            }
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
        .rmGlassCardBackground(cornerRadius: 12, fallbackFill: Color(.systemBackground))
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
        let appearance = ResultTilePresentation.appearance(for: outcome.status)
        let tileColor = appearance.color
        let badgeIcon = appearance.icon

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
                        .lineLimit(3)
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
            .rmGlassTintedCard(
                cornerRadius: 14,
                tint: tileColor.opacity(0.35),
                fallbackFill: tileColor.opacity(0.12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tileColor.opacity(0.25), lineWidth: 1)
            )
            .modifier(ResultTileGlassID(id: outcome.id, namespace: resultGlass))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("retest-\(outcome.id)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ResultTilePresentation.accessibilityLabel(name: outcome.name, status: outcome.status))
        .accessibilityHint("Double tap to retest")
    }

    // MARK: - PDF (share arrow + preview row share one generate path)

    #if os(iOS)
    /// On-device PDF preview affordance. Renders the SAME report as the top-right Share arrow
    /// (both go through DiagnosticReportShare.generatePDF) and opens it in Quick Look.
    @ViewBuilder
    private var generatePDFRow: some View {
        Button(action: previewPDF) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generate PDF")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Preview the full report on this device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isGeneratingPDF {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .rmGlassCardBackground(cornerRadius: 12, fallbackFill: Color(.systemBackground))
        }
        .buttonStyle(.plain)
        .disabled(isGeneratingPDF || runner.orderedOutcomes.isEmpty)
        .accessibilityIdentifier("generate-pdf")
    }

    /// Top-right arrow: build the report and present the system share sheet.
    private func sharePDF() {
        guard !isGeneratingPDF else { return }
        isGeneratingPDF = true
        DiagnosticReportShare.presentShareSheet(for: runner) { _ in
            isGeneratingPDF = false
        }
    }

    /// "Generate PDF" row: build the same report and preview it on-device (Quick Look).
    private func previewPDF() {
        guard !isGeneratingPDF else { return }
        isGeneratingPDF = true
        DiagnosticReportShare.presentPreview(for: runner) { _ in
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
            Task {
                await runner.retestAuto(test)
                autoSendIfPaired()   // re-send so the shop's copy reflects the retest (same session)
            }
        }
    }

    @ViewBuilder
    private func interactiveRetestSheet(_ test: any DiagnosticTest) -> some View {
        if let view = test.makeView(complete: { outcome in
            runner.record(outcome)
            retestTest = nil
            autoSendIfPaired()   // re-send so the shop's copy reflects the retest (same session)
        }) {
            view
        } else {
            Color.clear.onAppear { retestTest = nil }
        }
    }
}

/// Stable glass identity so a result tile morphs when it moves between sections on retest
/// (e.g. Failed → Passed). No-op below iOS 26.
private struct ResultTileGlassID: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}
