#if os(iOS)
import AVFoundation
import CoreMotion
import Accelerate

/// Streams band-passed microphone energy samples relative to a start time.
/// Applies a biquad band-pass filter centred ~190 Hz (Q≈2) to each audio buffer,
/// computes RMS, and emits (elapsed, rms) on the main actor.
@MainActor
final class MicBandEnergyProbe {
    private let engine = AVAudioEngine()
    private var onSample: ((Double, Double) -> Void)?
    private var startTime: Double = 0

    func start(startTime: Double, onSample: @escaping (Double, Double) -> Void) {
        #if targetEnvironment(simulator)
        return
        #else
        self.startTime = startTime
        self.onSample = onSample

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
        // A record session suppresses the Taptic Engine by default; explicitly re-permit haptics so
        // the vibration buzz can fire WHILE the mic records (Apple's documented fix for this conflict).
        try? session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try? session.setActive(true)

        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate

        // RBJ band-pass coefficients for f0=190 Hz, Q=2.0
        let f0: Double = 190.0
        let q: Double = 2.0
        let w0 = 2.0 * Double.pi * f0 / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let cosW0 = cos(w0)
        // band-pass: H(z) = alpha / (1 + alpha) * (1 - z^{-2})
        let b0 =  alpha
        let b1 =  0.0
        let b2 = -alpha
        let a0 =  1.0 + alpha
        let a1 = -2.0 * cosW0
        let a2 =  1.0 - alpha

        // normalise
        let nb0 = Float(b0 / a0)
        let nb1 = Float(b1 / a0)
        let nb2 = Float(b2 / a0)
        let na1 = Float(a1 / a0)
        let na2 = Float(a2 / a0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            var filtered = [Float](repeating: 0, count: frameCount)

            // Apply biquad sample-by-sample
            var x1: Float = 0, x2: Float = 0
            var y1: Float = 0, y2: Float = 0
            for i in 0..<frameCount {
                let x0 = channelData[i]
                let y0 = nb0 * x0 + nb1 * x1 + nb2 * x2 - na1 * y1 - na2 * y2
                filtered[i] = y0
                x2 = x1; x1 = x0
                y2 = y1; y1 = y0
            }

            // RMS of filtered signal
            var rms: Float = 0
            vDSP_rmsqv(filtered, 1, &rms, vDSP_Length(frameCount))

            let elapsed = CACurrentMediaTime() - startTime
            let rmsD = Double(rms)
            Task { @MainActor in
                self.onSample?(elapsed, rmsD)
            }
        }

        do {
            try engine.start()
        } catch {
            // If mic unavailable, silently fail — auto-detect won't pass, manual override available
        }
        #endif
    }

    func stop() {
        #if targetEnvironment(simulator)
        return
        #else
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}

/// Streams magnetometer deviation samples relative to a start time.
/// Establishes a baseline over the first ~0.4 s, then emits magnitude-of-deviation.
@MainActor
final class MagnetometerEnvelopeProbe {
    private let motionManager = CMMotionManager()
    private var onSample: ((Double, Double) -> Void)?
    private var startTime: Double = 0
    private var baselineSamples: [(x: Double, y: Double, z: Double)] = []
    private var baselineX: Double = 0
    private var baselineY: Double = 0
    private var baselineZ: Double = 0
    private var baselineSettled = false
    private let baselineDuration: Double = 0.4

    func start(startTime: Double, onSample: @escaping (Double, Double) -> Void) {
        #if targetEnvironment(simulator)
        return
        #else
        self.startTime = startTime
        self.onSample = onSample
        baselineSamples = []
        baselineSettled = false

        guard motionManager.isMagnetometerAvailable else { return }
        motionManager.magnetometerUpdateInterval = 1.0 / 100.0

        let queue = OperationQueue()
        motionManager.startMagnetometerUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            let elapsed = CACurrentMediaTime() - startTime
            let x = data.magneticField.x
            let y = data.magneticField.y
            let z = data.magneticField.z

            Task { @MainActor in
                if !self.baselineSettled {
                    self.baselineSamples.append((x, y, z))
                    if elapsed >= self.baselineDuration {
                        // Compute baseline mean
                        let n = Double(self.baselineSamples.count)
                        self.baselineX = self.baselineSamples.map { $0.x }.reduce(0, +) / n
                        self.baselineY = self.baselineSamples.map { $0.y }.reduce(0, +) / n
                        self.baselineZ = self.baselineSamples.map { $0.z }.reduce(0, +) / n
                        self.baselineSettled = true
                    }
                } else {
                    let dx = x - self.baselineX
                    let dy = y - self.baselineY
                    let dz = z - self.baselineZ
                    let magnitude = sqrt(dx*dx + dy*dy + dz*dz)
                    self.onSample?(elapsed, magnitude)
                }
            }
        }
        #endif
    }

    func stop() {
        #if targetEnvironment(simulator)
        return
        #else
        motionManager.stopMagnetometerUpdates()
        #endif
    }
}
#endif
