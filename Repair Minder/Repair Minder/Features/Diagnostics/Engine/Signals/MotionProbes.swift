import Foundation
#if os(iOS)
import CoreMotion

/// Peak-to-peak spread of a sample series — captures rapid oscillation (a vibrating motor) even when
/// the mean stays near 1 g, where mean-deviation barely moves.
private func peakToPeak(_ xs: [Double]) -> Double {
    guard let lo = xs.min(), let hi = xs.max() else { return 0 }
    return hi - lo
}

@MainActor
final class AccelProbeCM: AccelProbe {
    private let mm = CMMotionManager()
    func sampleBaseline(windowMs: Int, completion: @escaping (Double) -> Void) {
        #if targetEnvironment(simulator)
        completion(0); return
        #else
        guard mm.isAccelerometerAvailable else { completion(0); return }
        mm.accelerometerUpdateInterval = 1.0 / 100.0
        var mags: [Double] = []
        mm.startAccelerometerUpdates(to: .main) { data, _ in
            guard let a = data?.acceleration else { return }
            mags.append(sqrt(a.x*a.x + a.y*a.y + a.z*a.z))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(windowMs)/1000.0) { [weak self] in
            self?.mm.stopAccelerometerUpdates()
            // Resting energy floor as peak-to-peak of magnitude (same metric as samplePeak).
            completion(peakToPeak(mags))
        }
        #endif
    }
    func samplePeak(windowMs: Int, completion: @escaping (Double, Double) -> Void) {
        #if targetEnvironment(simulator)
        completion(0, 0); return
        #else
        guard mm.isAccelerometerAvailable else { completion(0, 0); return }
        mm.accelerometerUpdateInterval = 1.0 / 100.0
        var mags: [Double] = []
        mm.startAccelerometerUpdates(to: .main) { data, _ in
            guard let a = data?.acceleration else { return }
            mags.append(sqrt(a.x*a.x + a.y*a.y + a.z*a.z))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(windowMs)/1000.0) { [weak self] in
            self?.mm.stopAccelerometerUpdates()
            // Peak-to-peak of magnitude over the window — a buzzing motor produces large rapid swings
            // even though the mean stays ~1 g. First return value kept for signature compatibility.
            completion(0, peakToPeak(mags))
        }
        #endif
    }
}

/// Liveness probe used by pre-flight. Runs on the main actor (CoreMotion delivers to `.main`),
/// so captured state is mutated and read on one actor. Returns nil on the Simulator / when absent.
@MainActor
final class MotionAliveProbeCM: MotionAliveProbe {
    func accelerometerAlive(windowMs: Int) async -> (magnitude: Double, samples: Int)? {
        #if targetEnvironment(simulator)
        return nil
        #else
        let mm = CMMotionManager()
        guard mm.isAccelerometerAvailable else { return nil }
        mm.accelerometerUpdateInterval = 1.0 / 50.0
        var mags: [Double] = []
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<(magnitude: Double, samples: Int)?, Never>) in
                nonisolated(unsafe) var resumed = false
                mm.startAccelerometerUpdates(to: .main) { data, _ in
                    guard let a = data?.acceleration else { return }
                    mags.append(sqrt(a.x*a.x + a.y*a.y + a.z*a.z))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(windowMs) / 1000.0) {
                    guard !resumed else { return }
                    resumed = true
                    mm.stopAccelerometerUpdates()
                    cont.resume(returning: mags.isEmpty ? nil
                        : (magnitude: mags.reduce(0, +) / Double(mags.count), samples: mags.count))
                }
            }
        } onCancel: {
            Task { @MainActor in mm.stopAccelerometerUpdates() }
        }
        #endif
    }

    func gyroAlive(windowMs: Int) async -> Int? {
        #if targetEnvironment(simulator)
        return nil
        #else
        let mm = CMMotionManager()
        guard mm.isGyroAvailable else { return nil }
        mm.gyroUpdateInterval = 1.0 / 50.0
        var count = 0
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Int?, Never>) in
                nonisolated(unsafe) var resumed = false
                mm.startGyroUpdates(to: .main) { data, _ in if data != nil { count += 1 } }
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(windowMs) / 1000.0) {
                    guard !resumed else { return }
                    resumed = true
                    mm.stopGyroUpdates()
                    cont.resume(returning: count)
                }
            }
        } onCancel: {
            Task { @MainActor in mm.stopGyroUpdates() }
        }
        #endif
    }
}
#endif
