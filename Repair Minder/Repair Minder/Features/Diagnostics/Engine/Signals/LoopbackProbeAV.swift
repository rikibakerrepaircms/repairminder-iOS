import Foundation
import AVFoundation

@MainActor
final class LoopbackProbeAV: LoopbackProbe {
    private let engine = AVAudioEngine()
    private var player: AVAudioPlayerNode?
    private var peakDb: Double = -120

    func run(route: AudioRoute, durationMs: Int, onLevel: @escaping (Double) -> Void) {
        #if targetEnvironment(simulator)
        onLevel(-120); return
        #else
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
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
            let tone = AVAudioPlayerNode(); self.player = tone
            engine.attach(tone)
            engine.connect(tone, to: engine.mainMixerNode, format: format)
            let toneBuffer = LoopbackProbeAV.makeTone(format: format, hz: 1000, seconds: Double(durationMs)/1000.0)
            try engine.start()
            tone.scheduleBuffer(toneBuffer, at: nil, options: [], completionHandler: nil)
            tone.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(durationMs)/1000.0) { [weak self] in
                guard let self else { return }
                onLevel(self.peakDb); self.stop()
            }
        } catch { onLevel(-120) }
        #endif
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        player = nil
    }

    private static func makeTone(format: AVAudioFormat, hz: Double, seconds: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(format.sampleRate * max(0.1, seconds))
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        if let ch = buf.floatChannelData?[0] {
            for i in 0..<Int(frames) { ch[i] = Float(0.5 * sin(2 * Double.pi * hz * Double(i) / format.sampleRate)) }
        }
        return buf
    }
}
