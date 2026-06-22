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

/// Speaker result: both the loudspeaker and the earpiece must be heard by the mic.
enum SpeakerOutcome {
    static func result(loudPass: Bool, earPass: Bool) -> (status: TestStatus, details: [String: String]) {
        ((loudPass && earPass) ? .pass : .fail,
         ["loud": loudPass ? "pass" : "fail", "ear": earPass ? "pass" : "fail"])
    }
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
    @Published var loudState: TileState = .pending
    @Published var earState: TileState = .pending
    enum TileState { case pending, testing, pass, fail }
    private var cancelled = false
    init(probe: LoopbackProbe) { self.probe = probe }

    func run() async {
        phase = "Testing loudspeaker…"
        loudState = .testing
        let loud = await measure(.speaker, durationMs: 800)
        guard !cancelled else { return }
        let loudPass = LoopbackGate.heard(levelDb: loud, thresholdDb: -20)
        loudState = loudPass ? .pass : .fail

        phase = "Testing earpiece — keep quiet and still…"
        earState = .testing
        // The receiver is quiet, so give it a longer window and a more sensitive threshold.
        let ear = await measure(.receiver, durationMs: 1500)
        guard !cancelled else { return }
        let earPass = LoopbackGate.heard(levelDb: ear, thresholdDb: -38)
        earState = earPass ? .pass : .fail

        let (status, details) = SpeakerOutcome.result(loudPass: loudPass, earPass: earPass)
        outcome = diagnosticOutcome("speaker", "Speaker", status, details)
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
        // Record what we'd already established before the hang (e.g. loudspeaker may have passed)
        // rather than blanket-failing both fields, so the report matches the visible tiles.
        let loud = loudState == .pass ? "pass" : "fail"
        let ear = earState == .pass ? "pass" : "fail"
        outcome = diagnosticOutcome("speaker", "Speaker", .fail, ["reason": "no_speaker_signal", "loud": loud, "ear": ear])
    }

    private func measure(_ route: AudioRoute, durationMs: Int) async -> Double {
        await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            probe.run(route: route, durationMs: durationMs) { level in cont.resume(returning: level) }
        }
    }
}

private struct SpeakerTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var model = SpeakerViewModel(probe: LoopbackProbeAV())

    var body: some View {
        TestScaffold(
            title: "Speaker",
            instruction: "Keep quiet and hold still. The loudspeaker then the earpiece are each tested automatically through the microphone.",
            hints: ["Ensure the volume is not muted"],
            allowManualPass: false,
            onPass: {},
            onFail: { model.cancel(); complete(diagnosticOutcome("speaker", "Speaker", .fail)) },
            onSkip: { model.cancel(); complete(diagnosticOutcome("speaker", "Speaker", .skip)) }
        ) {
            VStack(spacing: 16) {
                speakerTile(icon: "speaker.wave.3.fill", title: "Loudspeaker", state: model.loudState)
                speakerTile(icon: "phone.fill", title: "Earpiece", state: model.earState)
                if !model.phase.isEmpty { Text(model.phase).font(.caption).foregroundStyle(.secondary) }
            }
            .task { await model.run() }
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 12_000_000_000)   // ~12s watchdog
                    model.failIfUnresolved()
                }
            }
            .onChange(of: model.outcome?.status) { _, _ in
                if let o = model.outcome { complete(o) }
            }
            .onDisappear { model.cancel() }   // stop the loopback probe if dismissed mid-run
        }
    }

    private func speakerTile(icon: String, title: String, state: SpeakerViewModel.TileState) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.accentColor)
            Text(title).font(.headline)
            Spacer()
            switch state {
            case .pending: Image(systemName: "circle").foregroundStyle(.secondary)
            case .testing: ProgressView()
            case .pass: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .fail: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }
        }
        .padding(12).background(Color.platformGray6).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: Microphone (per input data-source, sequential with 3 s window per source)

/// Meters a single AVAudioRecorder for up to `windowMs` ms; reports peak dBFS at end.
@MainActor private final class MicMeter: ObservableObject {
    @Published var level: Float = 0
    @Published var denied = false
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private(set) var recordingURL: URL?

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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mic-\(UUID().uuidString).caf")
        recordingURL = url
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
    @Published var currentIndex = 0
    @Published var level: Float = 0
    @Published var countdown = 3
    @Published var signalDetected = false
    @Published var denied = false
    @Published var done = false
    enum SourcePhase { case recording, playing, awaitingContinue }
    @Published var phase: SourcePhase = .recording

    private var meter = MicMeter()
    private var player: AVAudioPlayer?
    private var recordTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var didPlayback = false
    private let recordSeconds = 3

    var currentLabel: String { currentIndex < sources.count ? sources[currentIndex].label : "" }

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
        // Reset to an input-capable category before selecting the data source (playback leaves the
        // session on a state where setPreferredDataSource/Input can silently no-op).
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)
        if let inputs = session.availableInputs, let port = inputs.first,
           let ds = port.dataSources?.first(where: { $0.dataSourceName.lowercased() == sources[currentIndex].id }) {
            try? port.setPreferredDataSource(ds)
            try? session.setPreferredInput(port)
        }
        // Reset per-attempt state and start a FIXED-LENGTH recording.
        player?.stop()
        meter.stop(); meter = MicMeter()
        level = 0; signalDetected = false; countdown = recordSeconds; phase = .recording
        meter.start(onLevel: { [weak self] lvl in self?.level = lvl },
                    onDetect: { [weak self] in self?.signalDetected = true })   // flag only — do NOT advance
        // Poll for permission denial (requestRecordPermission is async).
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            if self.meter.denied { self.denied = true; self.finish() }
        }
        // Fixed 3s window with a visible 3→1 countdown, THEN finalise.
        recordTask?.cancel()
        recordTask = Task { @MainActor in
            for s in stride(from: recordSeconds, through: 1, by: -1) {
                self.countdown = s
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
            self.finalizeRecording()
        }
    }

    private func finalizeRecording() {
        let url = meter.recordingURL
        meter.stop()
        guard currentIndex < sources.count else { return }
        sources[currentIndex].result = signalDetected   // pass iff signal heard during the window
        playBack(url)
    }

    private func playBack(_ url: URL?) {
        guard let url else { phase = .awaitingContinue; return }
        didPlayback = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.overrideOutputAudioPort(.speaker)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
        phase = .playing
        let secs = player?.duration ?? 0
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(max(0.5, secs) * 1_000_000_000))
            if Task.isCancelled { return }
            if self.phase == .playing { self.phase = .awaitingContinue }
        }
    }

    /// Re-record the current source (same index) — used by "Record again".
    func recordAgain() {
        playbackTask?.cancel(); player?.stop()
        startCurrentSource()
    }

    /// Advance to the next source (or finish). The current source's result is already recorded.
    func advance() {
        recordTask?.cancel(); playbackTask?.cancel(); player?.stop()
        currentIndex += 1
        if currentIndex < sources.count { startCurrentSource() } else { finish() }
    }

    private func finish() {
        recordTask?.cancel(); playbackTask?.cancel(); meter.stop(); player?.stop()
        done = true
    }

    func stopAll() {
        recordTask?.cancel(); playbackTask?.cancel(); meter.stop(); player?.stop()
    }

    func outcome() -> TestOutcome {
        let perSource = Dictionary(uniqueKeysWithValues: sources.compactMap { s -> (String, Bool)? in
            guard let r = s.result else { return nil }
            return (s.id, r)
        })
        let (status, baseDetails) = MicSourceAggregate.result(perSource: perSource.isEmpty ? ["default": false] : perSource)
        var details = baseDetails
        if didPlayback { details["playback"] = "1" }
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
                        VStack(spacing: 10) {
                            switch model.phase {
                            case .recording:
                                Text("Recording \(model.currentLabel)… \(model.countdown)s")
                                    .font(.subheadline.weight(.semibold))
                                SignalMeterView(value: Double(model.level), threshold: 0.667, label: "Input level")
                                Text("Make a sound near this microphone")
                                    .font(.caption).foregroundStyle(.secondary)
                            case .playing:
                                Label("Playing back \(model.currentLabel)…", systemImage: "speaker.wave.2.fill")
                                    .font(.subheadline)
                            case .awaitingContinue:
                                if model.signalDetected {
                                    Label("Sound detected", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green).font(.subheadline)
                                } else {
                                    Label("No sound detected", systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange).font(.subheadline)
                                }
                                HStack(spacing: 12) {
                                    Button("Record again") { model.recordAgain() }
                                        .buttonStyle(.rmGlass())
                                    Button("Continue") { model.advance() }
                                        .buttonStyle(.rmGlassProminent())
                                        .accessibilityIdentifier("mic-continue")
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .onAppear {
                model.prepare()
                model.startCurrentSource()
            }
            .onDisappear { model.stopAll() }
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
            if isActive, model.phase == .recording { ProgressView().scaleEffect(0.7) }
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
            instruction: "Connect WIRED headphones (3.5mm or Lightning/USB-C). It passes automatically when a wired headphone output is detected. Bluetooth is not tested here.",
            hints: ["Plug in wired headphones — Bluetooth won’t pass"],
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
        // Wired headphones only — Bluetooth audio routes must not pass this test.
        if outs.contains(.headphones) {
            connected = true; finish(.pass, ["route": "wired", "type": "wired"])
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
