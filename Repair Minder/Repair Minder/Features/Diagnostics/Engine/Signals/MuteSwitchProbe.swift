// Features/Diagnostics/Engine/Signals/MuteSwitchProbe.swift
import Foundation
#if os(iOS)
import AVFoundation
import AudioToolbox
import QuartzCore

/// Infers the Ring/Silent state (or Action-button-Silent state) by playing a short silent system
/// sound and timing the completion callback: when silenced the system suppresses it and the callback
/// fires almost immediately; when not silenced it takes the sound's full duration. There is no public
/// API to read the switch directly — this is the standard technique.
@MainActor
final class MuteSwitchProbe {
    private let soundID: SystemSoundID
    /// Sounds shorter than this completion latency (callback delivery + main-queue hop) are treated
    /// as silenced. Silenced state returns in single-digit ms on shipping hardware; the 0.2s clip
    /// returns at ~0.2s when audible — 0.1s splits the two cleanly.
    private let silencedLatencyThreshold: CFTimeInterval = 0.1

    init() { soundID = Self.makeSilentSound() }
    deinit { if soundID != 0 { AudioServicesDisposeSystemSoundID(soundID) } }

    /// Plays the silent sound; calls back `true` if the device is currently silenced. If the sound
    /// couldn't be created (soundID == 0), reports not-silenced deterministically rather than
    /// hanging the caller waiting for a completion that may never arrive.
    func sampleSilenced(_ completion: @escaping (Bool) -> Void) {
        #if targetEnvironment(simulator)
        completion(false); return
        #else
        guard soundID != 0 else { completion(false); return }
        let start = CACurrentMediaTime()
        AudioServicesPlaySystemSoundWithCompletion(soundID) {
            let elapsed = CACurrentMediaTime() - start
            DispatchQueue.main.async { completion(elapsed < self.silencedLatencyThreshold) }
        }
        #endif
    }

    /// Writes a ~0.2s silent CAF and registers it as a system sound. Validates the cached file and
    /// regenerates it once if registration fails (a prior crash could leave a corrupt/partial file
    /// that would otherwise permanently break the probe).
    private static func makeSilentSound() -> SystemSoundID {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rm-silent.caf")
        func writeSilence() {
            try? FileManager.default.removeItem(at: url)
            guard let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
                  let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(44100 * 0.2))
            else { return }
            buf.frameLength = AVAudioFrameCount(44100 * 0.2)   // zero-filled = silence
            if let file = try? AVAudioFile(forWriting: url, settings: fmt.settings) {
                try? file.write(from: buf)
            }
        }
        // A valid silent CAF is well over 1 KB; anything smaller (or missing) is rewritten.
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
        if (size ?? 0) < 1024 { writeSilence() }
        var sid: SystemSoundID = 0
        if AudioServicesCreateSystemSoundID(url as CFURL, &sid) != noErr || sid == 0 {
            // Cached file may be corrupt — regenerate once and retry.
            writeSilence()
            sid = 0
            AudioServicesCreateSystemSoundID(url as CFURL, &sid)
        }
        return sid
    }
}
#endif
