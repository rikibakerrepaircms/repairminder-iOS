import Foundation

// MARK: - Pure gate functions (unit-tested without hardware)

enum LightGate {
    /// Minimum baseline luminance (0–255) we trust as a real read. Below this the camera is
    /// effectively dark (covered / dead) and no relative jump should count as a pass.
    static let baselineFloor: Double = 3.0

    /// Passes only when BOTH a relative jump (≥ thresholdPct of baseline) AND an absolute jump
    /// (≥ minAbsoluteDelta in luminance units) occur, and the baseline is above the trust floor.
    static func passes(baseline: Double, peak: Double, thresholdPct: Double, minAbsoluteDelta: Double) -> Bool {
        guard baseline >= baselineFloor else { return false }
        let absoluteDelta = peak - baseline
        guard absoluteDelta >= minAbsoluteDelta else { return false }
        return absoluteDelta / baseline * 100.0 >= thresholdPct
    }
}

enum VibrationGate {
    /// Peak acceleration magnitude minus resting noise must exceed minDelta (g).
    static func spiked(restingNoise: Double, peak: Double, minDelta: Double) -> Bool {
        (peak - restingNoise) >= minDelta
    }
}

enum MotionAliveGate {
    /// Accelerometer is "alive" when it delivers samples and the total magnitude sits near gravity
    /// (a dead/stuck sensor reports ~0 or a wildly off value).
    static func accelerometerAlive(magnitude: Double, samples: Int) -> Bool {
        samples >= 5 && magnitude >= 0.7 && magnitude <= 1.3
    }
    /// Gyroscope is "alive" when it delivers samples within the window (it reads ~0 at rest, so we
    /// can only confirm it responds, not its range — full range is the interactive test).
    static func gyroAlive(samples: Int) -> Bool { samples >= 5 }
}

enum LoopbackGate {
    static func heard(levelDb: Double, thresholdDb: Double) -> Bool { levelDb >= thresholdDb }
}

// MARK: - Probe protocols (real impls guarded for device in Task 1.2; fakes in tests)

/// Streams average-luminance samples (~0–255) from a camera position.
protocol LuminanceProbe: Sendable {
    @MainActor func start(onSample: @escaping (Double) -> Void)
    @MainActor func stop()
}

/// Streams QR/barcode payloads recognised through a specific camera device.
protocol QRProbe: Sendable {
    @MainActor func start(onCode: @escaping (String) -> Void)
    @MainActor func stop()
}

/// Plays a tone on a chosen route and reports peak mic level (dBFS).
protocol LoopbackProbe: Sendable {
    @MainActor func run(route: AudioRoute, durationMs: Int, onLevel: @escaping (Double) -> Void)
    @MainActor func stop()
}

enum AudioRoute: String, Sendable { case speaker, receiver }

/// Reports resting + peak magnitude of user acceleration (g) over a short window.
protocol AccelProbe: Sendable {
    /// Average resting deviation from gravity (g) over the window — sample this BEFORE any stimulus.
    @MainActor func sampleBaseline(windowMs: Int, completion: @escaping (_ resting: Double) -> Void)
    @MainActor func samplePeak(windowMs: Int, completion: @escaping (_ resting: Double, _ peak: Double) -> Void)
}

/// Brief liveness check for the motion sensors used by pre-flight (no user gesture). Returns nil
/// when the sensor is unavailable (e.g. on the Simulator) so the test falls back to interactive.
protocol MotionAliveProbe: Sendable {
    /// Average total acceleration magnitude (g) and sample count over the window; nil if unavailable.
    func accelerometerAlive(windowMs: Int) async -> (magnitude: Double, samples: Int)?
    /// Gyro sample count over the window; nil if unavailable.
    func gyroAlive(windowMs: Int) async -> Int?
}

/// Emits a tick per valid depth frame captured (TrueDepth or LiDAR).
protocol DepthProbe: Sendable {
    @MainActor func start(onDepthFrame: @escaping () -> Void)
    @MainActor func stop()
}

/// Battery snapshot reader.
protocol BatteryProbing: Sendable {
    @MainActor func snapshot() -> BatterySnapshot
}

struct BatterySnapshot: Sendable, Equatable {
    var levelPct: Int          // -1 if unknown
    var state: String          // unplugged/charging/full/unknown
    var thermalState: String   // nominal/fair/serious/critical
    var lowPowerMode: Bool
}
