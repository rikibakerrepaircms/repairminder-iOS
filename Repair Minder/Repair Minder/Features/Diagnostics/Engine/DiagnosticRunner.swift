// Features/Diagnostics/Engine/DiagnosticRunner.swift
import Foundation

/// Owns selection + results for a diagnostic session. Automatic tests run via `runAuto()`;
/// interactive tests are driven by the runner UI which calls `record(_:)` per test.
/// Results are keyed by test id (latest wins) so retesting overwrites cleanly.
@MainActor
final class DiagnosticRunner: ObservableObject {
    /// Where a session is in its lifecycle. Lives on the runner (not the runner *view*) so backing
    /// out of a test and re-entering resumes where the user left off instead of restarting.
    enum RunPhase { case permissions, preparing, interactive, finished }

    let tests: [DiagnosticTest]
    @Published private(set) var selectedIds: Set<String> = []
    @Published private(set) var outcomes: [String: TestOutcome] = [:]
    @Published private(set) var autoRan = false
    @Published var phase: RunPhase = .permissions
    @Published var interactiveIndex = 0
    /// Interactive tests resolved during the preparing phase by `preflight()` — excluded from the
    /// interactive queue. Stable during the interactive phase so index-based advancement is unaffected.
    @Published private(set) var preflightResolvedIds: Set<String> = []
    /// Guard so pre-flight only runs once per session (re-entering the runner must not re-run it).
    @Published private(set) var preflightRan = false
    /// Permission outcomes from the permission phase, keyed by permission. A value of `false` means
    /// denied; a missing key means "not denied" (so an empty map is a no-op — preserves prior behaviour).
    @Published var grantedPermissions: [DiagnosticPermission: Bool] = [:]

    /// Tests whose background pass earns a 1–2s banner during preparing, in display order.
    static let backgroundBannerIds = ["wifi", "accelerometer", "gyroscope", "bluetooth"]

    /// The backend session for live (incremental) reporting, opened at run start on a
    /// shop-paired device (see `beginLiveSessionIfPaired`). `nil` for an unpaired consumer run,
    /// or if opening it hasn't succeeded (yet) — those cases stay on the batch `transmit` path.
    @Published private(set) var liveSession: DiagnosticSessionResponse? = nil
    /// Raised when a live submit is rejected with `409 session_closed` (the run had timed out on
    /// inactivity). Drives the Resume / Start-again prompt; cleared by `resumeLive` /
    /// `startNewRunFromPrompt`. Default false so an ordinary run never shows the prompt.
    @Published private(set) var resumePrompt: Bool = false
    /// The outcome whose live submit hit `session_closed`, stashed so whichever choice the operator
    /// makes (Resume or Start again) can re-submit it once the session is live again.
    private var pendingClosedOutcome: TestOutcome?
    /// Test-injected transport (unit tests only) — always wins over the default resolution.
    private let injectedDiagnosticsAPI: DiagnosticsAPI?
    /// In-flight fire-and-forget live-submit tasks, tracked ONLY so tests can await them
    /// deterministically (`waitForPendingLiveSubmits`) — production call sites never read this.
    private var pendingLiveSubmits: [Task<Void, Never>] = []

    init(tests: [DiagnosticTest], diagnosticsAPI: DiagnosticsAPI? = nil) {
        self.tests = tests
        self.injectedDiagnosticsAPI = diagnosticsAPI
    }

    // MARK: Report identity
    /// Unique reference for this run, generated lazily on first use (when the report is shared
    /// or results transmitted) and stable thereafter. Shared by the PDF report and the transmit
    /// payload so the customer's report and the results we log carry the same id. Cleared by reset().
    private var _reportID: String?
    private var _reportDate: Date?
    private func reportIdentity() -> (id: String, date: Date) {
        if let id = _reportID, let date = _reportDate { return (id, date) }
        let date = Date()
        let id = DiagnosticReportID.generate(date: date)
        _reportID = id; _reportDate = date
        return (id, date)
    }
    var reportID: String { reportIdentity().id }
    var reportDate: Date { reportIdentity().date }

    /// True once a run is underway but not yet finished — drives the "Resume" affordance.
    var isInProgress: Bool { phase != .finished && (autoRan || interactiveIndex > 0) }

    /// Clear results and rewind to the start so the next Start is a fresh run (e.g. after the user
    /// completed a session and came back to change their selection).
    func reset() {
        outcomes = [:]
        autoRan = false
        interactiveIndex = 0
        preflightResolvedIds = []
        preflightRan = false
        phase = .permissions
        _reportID = nil          // a fresh run gets a fresh report reference
        _reportDate = nil
        liveSession = nil        // a fresh run gets a fresh live session too (new report_id)
    }

    // MARK: Selection
    var selectedTests: [DiagnosticTest] { tests.filter { selectedIds.contains($0.id) } }
    var selectedInteractiveTests: [DiagnosticTest] {
        selectedTests.filter { $0.requiresInteraction && $0.isSupported && !preflightResolvedIds.contains($0.id) }
    }
    /// Supported automatic tests resolved during the preparing phase, shown as a live checklist.
    /// Unsupported tests are excluded (capability exclusion).
    var autoChecklistTests: [DiagnosticTest] {
        selectedTests.filter { !$0.requiresInteraction && $0.isSupported }
    }
    var currentInteractiveTest: DiagnosticTest? {
        let list = selectedInteractiveTests
        return interactiveIndex < list.count ? list[interactiveIndex] : nil
    }
    func select(ids: [String]) { selectedIds = Set(ids) }
    /// Select every test the current device actually supports. Unsupported tests are never selected.
    func selectAll() { selectedIds = Set(tests.filter { $0.isSupported }.map(\.id)) }
    func toggle(_ id: String) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }
    func isSelected(_ id: String) -> Bool { selectedIds.contains(id) }

    /// A test's permissions are satisfied unless a required permission is explicitly denied
    /// (granted map value == false). Absent keys are treated as not-denied so an empty map is a no-op.
    func permissionsSatisfied(for test: DiagnosticTest) -> Bool {
        test.requiredPermissions.allSatisfy { grantedPermissions[$0] != false }
    }

    // MARK: Results
    /// Records the outcome locally AND — on a shop-paired device with a live session open —
    /// posts it to the backend immediately (live). A retest calls this again for the same id;
    /// the local map overwrites (existing behaviour) and the live POST re-submits under the
    /// same `test_name` (the Worker UPSERTs), so the dashboard reflects the latest attempt.
    func record(_ outcome: TestOutcome) {
        outcomes[outcome.id] = outcome
        submitLive(outcome)
    }
    func outcome(for id: String) -> TestOutcome? { outcomes[id] }

    /// Run all selected automatic, supported tests. Unsupported selections are dropped entirely
    /// (capability exclusion: never run, graded, or reported). Opens the live backend session
    /// FIRST (if paired) so the dashboard sees the run as `in_progress` from the very start,
    /// before the first result exists.
    func runAuto() async {
        _ = try? await beginLiveSessionIfPaired()
        for test in selectedTests where test.isSupported && !test.requiresInteraction {
            record(await test.run())
        }
        autoRan = true
    }

    // MARK: Live (incremental) reporting

    /// The transport used for live reporting. A test-injected API always wins. Otherwise this
    /// mirrors the existing UI-test-stub convention used by `SummaryView`/`TransmitView`, and —
    /// outside of that — is suppressed entirely inside a unit-test host process (`XCTestCase`
    /// present) so the runner's existing unit-test suite (which constructs runners directly and
    /// never expects network I/O) can't flake by hitting production if `DiagnosticsShopPairing`
    /// state happens to leak between tests.
    private var liveService: DiagnosticsService? {
        if let injectedDiagnosticsAPI { return DiagnosticsService(api: injectedDiagnosticsAPI) }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestStubTransmit") {
            return DiagnosticsService(api: StubDiagnosticsAPI())
        }
        if NSClassFromString("XCTestCase") != nil { return nil }
        #endif
        return DiagnosticsService()
    }

    /// Best-effort device description available at the time it's needed — the marketing name is
    /// known instantly; the OS version only once `device_info` has actually run, so an early call
    /// (at run start) gets just the model name and a later one (e.g. a Summary-time catch-up)
    /// gets the fuller string. Never blocks on a test that hasn't run yet.
    private var currentDeviceDescription: String? {
        let os = outcomes["device_info"]?.details?["os_version"]
        let parts = [DeviceModelName.marketingName, os].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Open the live backend session, if this device is paired to a shop (token or remembered
    /// shop code) and one isn't already open. An unpaired (consumer) run never opens one here —
    /// we don't know which company to attribute results to until the user types a shop code at
    /// Submit time, so that path stays on the batch `transmit` flow. Safe to call repeatedly
    /// (fast no-op once `liveSession` is set); on success, catches up any outcomes already
    /// recorded before the session existed. Throws on failure so callers can classify
    /// revoked-vs-transient (`DiagnosticsTransmitOutcome`); `runAuto` swallows this (best-effort
    /// at run start — the batch path at Submit time is the fallback).
    @discardableResult
    func beginLiveSessionIfPaired() async throws -> DiagnosticSessionResponse? {
        guard let service = liveService, DiagnosticsShopPairing.isPaired else { return nil }
        if let liveSession { return liveSession }
        let session = try await service.begin(
            shopCode: DiagnosticsShopPairing.shopCode, pairingToken: DiagnosticsShopPairing.token,
            platform: "ios", imei: nil, serial: nil, deviceDescription: currentDeviceDescription,
            reportID: reportID, totalTests: selectedTests.count,
            startedAt: ISO8601DateFormatter().string(from: Date()),
            selectedTests: selectedTests.map(\.id))
        liveSession = session
        DiagnosticsShopPairing.setName(session.companyName)
        for outcome in orderedOutcomes { submitLive(outcome) }   // catch up anything recorded before now
        return session
    }

    /// Ensure a server session exists before generating/sharing the report — the report HTML is
    /// fetched from the Worker (`DiagnosticReportShare`), so a real session is required even for a
    /// never-paired (consumer) run: reuses `liveSession` if already open; else opens one via
    /// `beginLiveSessionIfPaired()` on a paired device; else (fully unpaired) creates an ANONYMOUS
    /// session — neither `shopCode` nor `pairingToken` — which the Worker routes to the sentinel
    /// company. Idempotent: a second call after either branch just returns the now-set
    /// `liveSession`. Throws `DiagnosticsError.sessionUnavailable` if no transport is available
    /// (e.g. inside the unit-test host, where `liveService` deliberately suppresses network I/O).
    @discardableResult
    func ensureSession() async throws -> DiagnosticSessionResponse {
        if let liveSession { return liveSession }
        if let paired = try await beginLiveSessionIfPaired() { return paired }
        guard let service = liveService else { throw DiagnosticsError.sessionUnavailable }
        let session = try await service.begin(
            shopCode: nil, pairingToken: nil, platform: "ios", imei: nil, serial: nil,
            deviceDescription: currentDeviceDescription, reportID: reportID,
            totalTests: selectedTests.count, startedAt: ISO8601DateFormatter().string(from: Date()),
            selectedTests: selectedTests.map(\.id))
        liveSession = session
        for outcome in orderedOutcomes { submitLive(outcome) }   // catch up anything recorded before now
        return session
    }

    /// Fire-and-forget live submit for a just-recorded outcome. No-op when there's no live
    /// session (unpaired run, or `beginLiveSessionIfPaired` hasn't succeeded). A transient
    /// failure here is swallowed rather than buffered — buffering would replay through
    /// `complete` on the next flush, which must only ever fire from the operator's explicit
    /// Submit/Finish tap; the eventual Submit sends the full outcome set again (idempotent
    /// UPSERT) and buffers on failure exactly as before (`TransmitView.submit`).
    private func submitLive(_ outcome: TestOutcome) {
        guard let session = liveSession, let service = liveService else { return }
        pendingLiveSubmits.append(Task { @MainActor in
            do {
                try await service.submitOne(session: session, outcome: outcome)
            } catch {
                // A `409 session_closed` means the run timed out on inactivity: stash the outcome
                // and raise the Resume / Start-again prompt instead of silently reopening. Any other
                // error keeps today's swallow-and-buffer-at-Submit behaviour.
                if DiagnosticsResumeSignal.isSessionClosed(error) {
                    self.pendingClosedOutcome = outcome
                    self.resumePrompt = true
                }
            }
        })
    }

    /// Operator dismissed the prompt without choosing (Cancel / swipe). Keeps the stashed outcome so
    /// a later live submit or the explicit Submit tap still carries it; only lowers the prompt.
    func dismissResumePrompt() { resumePrompt = false }

    /// Operator chose "Resume diagnostics": reopen the SAME session on the Worker, then re-submit
    /// the stashed outcome so the run continues where it left off. Clears the prompt regardless.
    func resumeLive() async {
        defer { resumePrompt = false }
        guard let session = liveSession, let service = liveService else { return }
        try? await service.resume(sessionId: session.sessionId, token: session.sessionToken)
        if let o = pendingClosedOutcome { pendingClosedOutcome = nil; submitLive(o) }
    }

    /// Operator chose "Start a new run": drop the closed session + report id so a fresh
    /// `beginLiveSessionIfPaired()` opens a brand-new session (new `report_id`), then re-submit the
    /// stashed outcome against it. Clears the prompt.
    func startNewRunFromPrompt() async {
        resumePrompt = false
        liveSession = nil
        _reportID = nil          // fresh run -> fresh report_id -> new session/DO
        _reportDate = nil
        _ = try? await beginLiveSessionIfPaired()
        if let o = pendingClosedOutcome { pendingClosedOutcome = nil; submitLive(o) }
    }

    /// Test hook: await every live-submit task scheduled so far so assertions can be made
    /// deterministically instead of racing the fire-and-forget `Task` in `submitLive`. Not used
    /// by any production call site.
    func waitForPendingLiveSubmits() async {
        let pending = pendingLiveSubmits
        pendingLiveSubmits.removeAll()
        for task in pending { await task.value }
    }

    /// Resolve any selected interactive, supported test that can verify itself in the background.
    /// A `.pass` is recorded and the test is dropped from the interactive queue; anything else (or
    /// a nil result) leaves the test for the normal interactive flow. Runs at most once per session.
    func runPreflight() async {
        guard !preflightRan else { return }
        for test in selectedTests where test.requiresInteraction && test.isSupported && outcomes[test.id] == nil {
            guard permissionsSatisfied(for: test) else { continue }   // denied perms can't pass — don't spin the probe
            if let outcome = await test.preflight(), outcome.status == .pass {
                record(outcome)
                preflightResolvedIds.insert(test.id)
            }
        }
        preflightRan = true
    }

    /// Background-resolved passes to celebrate with a banner during preparing (auto Wi-Fi + pre-flighted
    /// sensors/radio), in `backgroundBannerIds` order.
    var backgroundPassed: [TestOutcome] {
        Self.backgroundBannerIds.compactMap { outcomes[$0] }.filter { $0.status == .pass }
    }

    /// Banner-eligible tests that are actually selected, in banner order (denominator for the
    /// "Checking sensors N of M" progress shown during Preparing).
    var backgroundEligibleSelected: [DiagnosticTest] {
        Self.backgroundBannerIds.compactMap { id in selectedTests.first { $0.id == id } }
    }

    /// Re-run a single automatic test (interactive retest is handled by the UI).
    func retestAuto(_ test: DiagnosticTest) async {
        guard test.isSupported, !test.requiresInteraction else { return }
        record(await test.run())
    }

    // MARK: Derived
    var orderedOutcomes: [TestOutcome] { selectedTests.compactMap { outcomes[$0.id] } }
    var passed: [TestOutcome] { orderedOutcomes.filter { $0.status == .pass } }
    var failedOrSkipped: [TestOutcome] {
        orderedOutcomes.filter { $0.status == .fail || $0.status == .skip || $0.status == .error }
    }
    var allSelectedHaveOutcome: Bool { selectedTests.allSatisfy { outcomes[$0.id] != nil } }

    // MARK: Derived grade
    var grade: DiagnosticGrade { DiagnosticGrade.grade(for: orderedOutcomes) }
    /// Wire/legacy string ("pass"/"partial"/"fail") kept for existing callers.
    var overallResult: String {
        switch grade { case .bad: return "fail"; case .good: return "partial"; case .excellent: return "pass" }
    }
}
