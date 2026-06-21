import Foundation
import CoreMotion

@MainActor
final class AccelProbeCM: AccelProbe {
    private let mm = CMMotionManager()
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
