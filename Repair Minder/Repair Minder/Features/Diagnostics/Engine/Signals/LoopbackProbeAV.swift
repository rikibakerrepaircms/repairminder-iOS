import Foundation
import AVFoundation

@MainActor
final class LoopbackProbeAV: LoopbackProbe {
    private let engine = AVAudioEngine()
    private var player: AVAudioPlayerNode?
    private var peakDb: Double = -120
    private var levelReported = false

    func run(route: AudioRoute, durationMs: Int, onLevel: @escaping (Double) -> Void) {
        #if targetEnvironment(simulator)
        onLevel(-120); return
        #else
        levelReported = false
        // Report the measured level to the caller exactly once (the timeout and the failure paths
        // could otherwise both fire).
        func report(_ db: Double) {
            guard !levelReported else { return }
            levelReported = true
            onLevel(db)
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            try? session.overrideOutputAudioPort(route == .speaker ? .speaker : .none)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            peakDb = -120
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                guard let self, let ch = buffer.floatChannelData?[0] else { return }
                var peak: Float = 0
                for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(ch[i])) }
                let db = peak > 0 ? Double(20 * log10(peak)) : -120
                Task { @MainActor in self.peakDb = max(self.peakDb, db) }
            }
            guard let toneBuffer = LoopbackProbeAV.makeTone(format: format, hz: 1000, seconds: Double(durationMs)/1000.0) else {
                report(-120); stop(); return
            }
            let tone = AVAudioPlayerNode(); self.player = tone
            engine.attach(tone)
            engine.connect(tone, to: engine.mainMixerNode, format: format)
            try engine.start()
            tone.scheduleBuffer(toneBuffer, at: nil, options: [], completionHandler: nil)
            tone.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(durationMs)/1000.0) { [weak self] in
                guard let self else { return }
                report(self.peakDb); self.stop()
            }
        } catch { report(-120); stop() }
        #endif
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        player = nil
        #if !targetEnvironment(simulator)
        // Release the audio session so other audio (and later tests) aren't blocked.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private static func makeTone(format: AVAudioFormat, hz: Double, seconds: Double) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * max(0.1, seconds))
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        if let ch = buf.floatChannelData?[0] {
            for i in 0..<Int(frames) { ch[i] = Float(0.5 * sin(2 * Double.pi * hz * Double(i) / format.sampleRate)) }
        }
        return buf
    }
}
