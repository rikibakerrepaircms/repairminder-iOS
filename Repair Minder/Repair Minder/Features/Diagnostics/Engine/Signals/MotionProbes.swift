import Foundation
import CoreMotion

@MainActor
final class AccelProbeCM: AccelProbe {
    private let mm = CMMotionManager()
    func sampleBaseline(windowMs: Int, completion: @escaping (Double) -> Void) {
        #if targetEnvironment(simulator)
        completion(0); return
        #else
        guard mm.isAccelerometerAvailable else { completion(0); return }
        mm.accelerometerUpdateInterval = 1.0 / 50.0
        var deviations: [Double] = []
        mm.startAccelerometerUpdates(to: .main) { data, _ in
            guard let a = data?.acceleration else { return }
            deviations.append(abs(sqrt(a.x*a.x + a.y*a.y + a.z*a.z) - 1.0))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(windowMs)/1000.0) { [weak self] in
            self?.mm.stopAccelerometerUpdates()
            let resting = deviations.isEmpty ? 0 : deviations.reduce(0, +) / Double(deviations.count)
            completion(resting)
        }
        #endif
    }
    func samplePeak(windowMs: Int, completion: @escaping (Double, Double) -> Void) {
        #if targetEnvironment(simulator)
        completion(0, 0); return
        #else
        guard mm.isAccelerometerAvailable else { completion(0, 0); return }
        mm.accelerometerUpdateInterval = 1.0 / 50.0
        var deviations: [Double] = []
        mm.startAccelerometerUpdates(to: .main) { data, _ in
            guard let a = data?.acceleration else { return }
            let mag = sqrt(a.x*a.x + a.y*a.y + a.z*a.z)   // ~1g at rest
            deviations.append(abs(mag - 1.0))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(windowMs)/1000.0) { [weak self] in
            self?.mm.stopAccelerometerUpdates()
            let resting = deviations.prefix(5).reduce(0, +) / Double(max(1, min(5, deviations.count)))
            let peak = deviations.max() ?? 0
            completion(resting, peak)
        }
        #endif
    }
}

/// Liveness probe used by pre-flight. Samples on `.main` like AccelProbeCM so the captured arrays
/// are mutated and read on the same thread (no race). Returns nil on the Simulator / when absent.
final class MotionAliveProbeCM: MotionAliveProbe {
    func accelerometerAlive(windowMs: Int) async -> (magnitude: Double, samples: Int)? {
        #if targetEnvironment(simulator)
        return nil
        #else
        return await withCheckedContinuation { (cont: CheckedContinuation<(magnitude: Double, samples: Int)?, Never>) in
            let mm = CMMotionManager()
            guard mm.isAccelerometerAvailable else { cont.resume(returning: nil); return }
            mm.accelerometerUpdateInterval = 1.0 / 50.0
            var mags: [Double] = []
            mm.startAccelerometerUpdates(to: .main) { data, _ in
                guard let a = data?.acceleration else { return }
                mags.append(sqrt(a.x*a.x + a.y*a.y + a.z*a.z))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(windowMs) / 1000.0) {
                mm.stopAccelerometerUpdates()
                if mags.isEmpty { cont.resume(returning: nil) }
                else { cont.resume(returning: (magnitude: mags.reduce(0, +) / Double(mags.count), samples: mags.count)) }
            }
        }
        #endif
    }

    func gyroAlive(windowMs: Int) async -> Int? {
        #if targetEnvironment(simulator)
        return nil
        #else
        return await withCheckedContinuation { (cont: CheckedContinuation<Int?, Never>) in
            let mm = CMMotionManager()
            guard mm.isGyroAvailable else { cont.resume(returning: nil); return }
            mm.gyroUpdateInterval = 1.0 / 50.0
            var count = 0
            mm.startGyroUpdates(to: .main) { data, _ in if data != nil { count += 1 } }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(windowMs) / 1000.0) {
                mm.stopGyroUpdates()
                cont.resume(returning: count)
            }
        }
        #endif
    }
}
