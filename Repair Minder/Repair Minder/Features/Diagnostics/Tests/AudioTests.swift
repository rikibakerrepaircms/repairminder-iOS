// Features/Diagnostics/Tests/AudioTests.swift
// M360-parity "Audio": Speaker, Microphone (auto level), Headphones (auto route), Audio loopback (auto).
import SwiftUI
#if os(iOS)
import AVFoundation
#endif

struct SpeakerTest: DiagnosticTest {
    let id = "speaker"; let name = "Speaker"; let category: TestCategory = .audio
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(SpeakerTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

struct MicrophoneTest: DiagnosticTest {
    let id = "microphone"; let name = "Microphone"; let category: TestCategory = .audio
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

private func speak(_ text: String) {
    let u = AVSpeechUtterance(string: text)
    u.rate = AVSpeechUtteranceDefaultSpeechRate
    AVSpeechSynthesizer.shared.speak(u)
}

// AVSpeechSynthesizer must outlive the call → keep a singleton.
extension AVSpeechSynthesizer { static let shared = AVSpeechSynthesizer() }

// MARK: Speaker (speak a phrase; user confirms)

private struct SpeakerTestView: View {
    let complete: (TestOutcome) -> Void
    var body: some View {
        TestScaffold(
            title: "Speaker",
            instruction: "You should hear a spoken phrase from the loudspeaker. Tap Pass if it's clear.",
            hints: ["Turn the volume up"],
            allowManualPass: true,
            onPass: { complete(diagnosticOutcome("speaker", "Speaker", .pass)) },
            onFail: { complete(diagnosticOutcome("speaker", "Speaker", .fail)) },
            onSkip: { complete(diagnosticOutcome("speaker", "Speaker", .skip)) }
        ) {
            VStack(spacing: 12) {
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                Button("Play sound") { play() }.buttonStyle(.bordered)
            }
            .onAppear { try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.defaultToSpeaker]); try? AVAudioSession.sharedInstance().setActive(true); play() }
        }
    }
    private func play() { speak("Repair Minder speaker test. One. Two. Three.") }
}

// MARK: Microphone (live input level → auto-pass when sound detected)

@MainActor private final class MicMeter: ObservableObject {
    @Published var level: Float = 0
    @Published var denied = false
    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start(onDetect: @escaping () -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else { self.denied = true; return }
                self.begin(onDetect: onDetect)
            }
        }
    }
    private func begin(onDetect: @escaping () -> Void) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mic-test.caf")
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatAppleLossless, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let r = self.recorder else { return }
            r.updateMeters()
            let peak = r.peakPower(forChannel: 0)   // dBFS, -160…0
            Task { @MainActor in
                self.level = max(0, (peak + 60) / 60)   // 0…1
                if peak > -20 { onDetect() }
            }
        }
    }
    func stop() { timer?.invalidate(); timer = nil; recorder?.stop(); recorder = nil }
}

private struct MicrophoneTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var mic = MicMeter()
    var body: some View {
        TestScaffold(
            title: "Microphone",
            instruction: "Speak or tap near the device. It passes automatically when the microphone picks up sound.",
            hints: ["Say a few words"],
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            VStack(spacing: 10) {
                if mic.denied { Label("Microphone permission denied", systemImage: "xmark.circle").foregroundStyle(.red) }
                ProgressView(value: Double(mic.level)).tint(.green)
                Text("Input level").font(.caption).foregroundStyle(.secondary)
            }
            .onAppear { mic.start { finish(.pass, ["detected": "1"]) } }
        }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) { mic.stop(); complete(diagnosticOutcome("microphone", "Microphone", s, d)) }
}

// MARK: Headphones (auto-detect output route)

private struct HeadphonesTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var connected = false
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
            .onAppear { check(); NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in check() } }
        }
    }
    private func check() {
        let outs = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
        if outs.contains(where: { [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0) }) {
            connected = true; finish(.pass, ["route": outs.first?.rawValue ?? "headphones"])
        }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) { NotificationCenter.default.removeObserver(self); complete(diagnosticOutcome("headphones", "Headphones", s, d)) }
}
#endif
