// Features/Diagnostics/Tests/AudioTests.swift
// Audio: Speaker (mic-loopback gated), Microphone (per-source level), Headphones (auto route).
import SwiftUI
#if os(iOS)
import AVFoundation
#endif

struct SpeakerTest: DiagnosticTest {
    let id = "speaker"; let name = "Speaker"; let category: TestCategory = .audio
    var requiredPermissions: [DiagnosticPermission] { [.microphone] }
    let requiresInteraction = true
    #if targetEnvironment(simulator)
    var isSupported: Bool { false }
    #elseif os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(SpeakerTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

struct MicrophoneTest: DiagnosticTest {
    let id = "microphone"; let name = "Microphone"; let category: TestCategory = .audio
    var requiredPermissions: [DiagnosticPermission] { [.microphone] }
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(MicrophoneTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

struct HeadphonesTest: DiagnosticTest {
    let id = "headphones"; let name = "Headphones"; let category: TestCategory = .audio
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(HeadphonesTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

#if os(iOS)

// MARK: Speaker (mic-loopback gated; earpiece best-effort)

@MainActor final class SpeakerViewModel: ObservableObject {
    private let probe: LoopbackProbe
    @Published var outcome: TestOutcome?
    @Published var phase = ""
    private var cancelled = false
    init(probe: LoopbackProbe) { self.probe = probe }

    func run() async {
        phase = "Testing loudspeaker…"
        let loud = await measure(.speaker)
        guard !cancelled else { return }
        phase = "Testing earpiece…"
        let ear = await measure(.receiver)
        guard !cancelled else { return }
        let loudPass = LoopbackGate.heard(levelDb: loud, thresholdDb: -20)
        let earPass = LoopbackGate.heard(levelDb: ear, thresholdDb: -20)
        let details = ["loud": loudPass ? "pass" : "fail", "ear": earPass ? "pass" : "n/a"]
        outcome = diagnosticOutcome("speaker", "Speaker", loudPass ? .pass : .fail, details)
    }

    func cancel() {
        cancelled = true
        probe.stop()
    }

    /// Watchdog: a hung/dead loopback probe can leave `run()` awaiting forever with no outcome.
    /// Auto-fail in that case (not skip). No-op if already cancelled or an outcome was produced
    /// (single-shot guards: `cancelled`, `outcome == nil`).
    func failIfUnresolved() {
        guard !cancelled, outcome == nil else { return }
        probe.stop()
        outcome = diagnosticOutcome("speaker", "Speaker", .fail, ["reason": "no_speaker_signal"])
    }

    private func measure(_ route: AudioRoute) async -> Double {
        await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            probe.run(route: route, durationMs: 800) { level in cont.resume(returning: level) }
        }
    }
}

private struct SpeakerTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var model = SpeakerViewModel(probe: LoopbackProbeAV())

    var body: some View {
        TestScaffold(
            title: "Speaker",
            instruction: "Hold the device still and keep quiet. The loudspeaker and earpiece are tested automatically via the microphone.",
            hints: ["Ensure the volume is not muted"],
            allowManualPass: false,
            onPass: {},
            onFail: { model.cancel(); complete(diagnosticOutcome("speaker", "Speaker", .fail)) },
            onSkip: { model.cancel(); complete(diagnosticOutcome("speaker", "Speaker", .skip)) }
        ) {
            VStack(spacing: 12) {
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                if !model.phase.isEmpty { ProgressView(model.phase) }
            }
            .task { await model.run() }
            .onAppear {
                // Bounded watchdog: both routes measure ~800ms each (~1.6s); allow ~10s before a
                // hung probe auto-fails (not skip). Single-shot via the model's own guards.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 10_000_000_000)   // ~10s
                    model.failIfUnresolved()
                }
            }
            .onChange(of: model.outcome?.status) { _, _ in
                if let o = model.outcome { complete(o) }
            }
        }
    }
}

// MARK: Microphone (per input data-source, sequential with 3 s window per source)

/// Meters a single AVAudioRecorder for up to `windowMs` ms; reports peak dBFS at end.
@MainActor private final class MicMeter: ObservableObject {
    @Published var level: Float = 0
    @Published var denied = false
    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start(onLevel: @escaping (Float) -> Void, onDetect: @escaping () -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else { self.denied = true; return }
                self.begin(onLevel: onLevel, onDetect: onDetect)
            }
        }
    }
    private func begin(onLevel: @escaping (Float) -> Void, onDetect: @escaping () -> Void) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mic-test.caf")
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatAppleLossless, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let r = self.recorder else { return }
                r.updateMeters()
                let peak = r.peakPower(forChannel: 0)   // dBFS, -160…0
                self.level = max(0, (peak + 60) / 60)   // 0…1 normalised for UI
                onLevel(self.level)
                if peak > -20 { onDetect() }            // ~0.667 normalised — quiet sounds won't pass
            }
        }
    }
    func stop() { timer?.invalidate(); timer = nil; recorder?.stop(); recorder = nil }
}

// MARK: Per-source sequencer

private struct MicSource: Identifiable {
    let id: String          // "bottom", "front", "back", or "default"
    let label: String       // human-readable
    var result: Bool?       // nil = not yet tested
}

@MainActor private final class MicrophoneViewModel: ObservableObject {
    @Published var sources: [MicSource] = []
    @Published var currentIndex: Int = 0
    @Published var level: Float = 0
    @Published var denied = false
    @Published var done = false

    private var meter = MicMeter()
    private var timeoutTask: Task<Void, Never>?

    // Build source list from AVAudioSession, falling back to a single "default".
    func prepare() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)

        if let inputs = session.availableInputs,
           let port = inputs.first,
           let dataSources = port.dataSources, !dataSources.isEmpty {
            sources = dataSources.map { ds in
                let key = ds.dataSourceName.lowercased()
                let label: String
                switch key {
                case let k where k.contains("bottom"): label = "Bottom mic"
                case let k where k.contains("front"):  label = "Front mic"
                case let k where k.contains("back"):   label = "Back mic"
                default:                               label = ds.dataSourceName
                }
                return MicSource(id: key, label: label)
            }
        } else {
            sources = [MicSource(id: "default", label: "Microphone")]
        }
    }

    func startCurrentSource() {
        guard currentIndex < sources.count else { finish(); return }
        let session = AVAudioSession.sharedInstance()
        // Point session at this data source
        if let inputs = session.availableInputs,
           let port = inputs.first,
           let ds = port.dataSources?.first(where: { $0.dataSourceName.lowercased() == sources[currentIndex].id }) {
            try? port.setPreferredDataSource(ds)
            try? session.setPreferredInput(port)
        }
        meter.stop()
        meter = MicMeter()
        level = 0
        timeoutTask?.cancel()

        meter.start(onLevel: { [weak self] lvl in self?.level = lvl }, onDetect: { [weak self] in
            guard let self else { return }
            self.markCurrent(pass: true)
        })
        // Observe denied via binding on next runloop
        Task { @MainActor in
            // Poll denial once (requestRecordPermission is async)
            try? await Task.sleep(nanoseconds: 200_000_000)
            if self.meter.denied { self.denied = true; self.finish() }
        }
        // 3-second timeout per source
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.markCurrent(pass: false)
        }
    }

    private func markCurrent(pass: Bool) {
        timeoutTask?.cancel()
        meter.stop()
        guard currentIndex < sources.count else { return }
        sources[currentIndex].result = pass
        currentIndex += 1
        if currentIndex < sources.count {
            startCurrentSource()
        } else {
            finish()
        }
    }

    private func finish() {
        timeoutTask?.cancel()
        meter.stop()
        done = true
    }

    func stopAll() {
        timeoutTask?.cancel()
        meter.stop()
    }

    func outcome() -> TestOutcome {
        let perSource = Dictionary(uniqueKeysWithValues: sources.compactMap { s -> (String, Bool)? in
            guard let r = s.result else { return nil }
            return (s.id, r)
        })
        let (status, details) = MicSourceAggregate.result(perSource: perSource.isEmpty ? ["default": false] : perSource)
        return diagnosticOutcome("microphone", "Microphone", status, details)
    }
}

private struct MicrophoneTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var model = MicrophoneViewModel()

    var body: some View {
        TestScaffold(
            title: "Microphone",
            instruction: "Speak or tap near each microphone location when prompted. Each source is tested for 3 seconds.",
            hints: ["Say 'test' or tap the device near each mic"],
            allowManualPass: false,
            onPass: {},
            onFail: { finish(.fail) },
            onSkip: { finish(.skip) }
        ) {
            VStack(spacing: 16) {
                if model.denied {
                    Label("Microphone permission denied", systemImage: "xmark.circle").foregroundStyle(.red)
                } else {
                    ForEach(model.sources.indices, id: \.self) { i in
                        sourceRow(index: i)
                    }
                    if model.currentIndex < model.sources.count {
                        VStack(spacing: 6) {
                            // Live input level. Fills as sound is picked up and turns green once it
                            // crosses the pass threshold (~ -20 dBFS → 0.667 normalised); quiet
                            // background noise stays below it and won't pass the test.
                            SignalMeterView(value: Double(model.level), threshold: 0.667, label: "Input level")
                            Text("Make a sound near the mic until the bar fills past the line")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .onAppear {
                model.prepare()
                model.startCurrentSource()
            }
            .onChange(of: model.done) { _, done in
                if done { complete(model.outcome()) }
            }
        }
    }

    @ViewBuilder private func sourceRow(index i: Int) -> some View {
        let src = model.sources[i]
        let isActive = i == model.currentIndex
        HStack {
            Image(systemName: rowIcon(src.result, isActive: isActive))
                .foregroundStyle(rowColor(src.result, isActive: isActive))
                .frame(width: 24)
            Text(src.label).font(.subheadline)
            Spacer()
            if isActive { ProgressView().scaleEffect(0.7) }
        }
        .padding(.vertical, 4)
    }

    private func rowIcon(_ result: Bool?, isActive: Bool) -> String {
        if let r = result { return r ? "checkmark.circle.fill" : "xmark.circle.fill" }
        return isActive ? "mic.fill" : "circle"
    }
    private func rowColor(_ result: Bool?, isActive: Bool) -> Color {
        if let r = result { return r ? .green : .red }
        return isActive ? .accentColor : .secondary
    }

    private func finish(_ s: TestStatus) {
        model.stopAll()
        complete(diagnosticOutcome("microphone", "Microphone", s))
    }
}

// MARK: Headphones (auto-detect output route)

private struct HeadphonesTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var connected = false
    @State private var observer: NSObjectProtocol?
    @State private var done = false
    var body: some View {
        TestScaffold(
            title: "Headphones",
            instruction: "Connect wired or Bluetooth headphones. It passes automatically when a headphone output is detected.",
            hints: ["With nothing connected this shows ‘Not connected’"],
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            VStack(spacing: 8) {
                Image(systemName: connected ? "headphones" : "headphones.slash" ).font(.system(size: 44))
                    .foregroundStyle(connected ? .green : .secondary)
                Text(connected ? "Connected" : "Not connected").font(.subheadline)
            }
            .onAppear {
                check()
                observer = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in check() }
            }
            .onDisappear { removeObserver() }
        }
    }
    private func check() {
        let outs = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
        if outs.contains(where: { [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0) }) {
            connected = true; finish(.pass, ["route": outs.first?.rawValue ?? "headphones"])
        }
    }
    private func removeObserver() {
        if let obs = observer { NotificationCenter.default.removeObserver(obs); observer = nil }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) {
        guard !done else { return }
        done = true
        removeObserver()
        complete(diagnosticOutcome("headphones", "Headphones", s, d))
    }
}
#endif
