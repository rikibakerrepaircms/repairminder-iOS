import Foundation

/// A randomized on/off buzz pattern. Each run differs so ambient noise / replay can't match it.
struct VibrationCode: Equatable {
    let slots: [Bool]     // true = buzz ON for that slot, false = OFF
    let slotS: Double     // seconds per slot

    /// Generate a random code: `count` slots, each ON with ~50% probability, but guaranteed to have
    /// at least 2 ON and 2 OFF slots (so correlation has both classes). Caller supplies randomness.
    static func random(count: Int = 6, slotS: Double = 0.35, rng: () -> Double) -> VibrationCode {
        var slots: [Bool] = []
        repeat {
            slots = (0..<count).map { _ in rng() < 0.5 }
        } while slots.filter({ $0 }).count < 2 || slots.filter({ !$0 }).count < 2
        return VibrationCode(slots: slots, slotS: slotS)
    }
}

/// Fusion scoring — pure, unit-tested. Buckets sensor samples into the code's slots and scores how
/// strongly the ON slots stand out from the OFF slots; a real coded vibration scores high, ambient
/// noise scores ~0.
enum VibrationFusion {
    /// Mean sensor value per slot. `samples` are (timeSeconds, value) relative to the code start.
    static func slotEnergies(samples: [(t: Double, v: Double)], slotS: Double, slotCount: Int) -> [Double] {
        var sums = [Double](repeating: 0, count: slotCount)
        var counts = [Int](repeating: 0, count: slotCount)
        for s in samples {
            let idx = Int(s.t / slotS)
            if idx >= 0, idx < slotCount { sums[idx] += s.v; counts[idx] += 1 }
        }
        return (0..<slotCount).map { counts[$0] > 0 ? sums[$0] / Double(counts[$0]) : 0 }
    }

    /// Correlation score = how much higher ON-slot energy is than OFF-slot energy, normalised.
    /// 0 when ON≈OFF (noise); large when ON≫OFF (real coded vibration). Returns 0 if degenerate.
    static func score(slotEnergies: [Double], code: VibrationCode) -> Double {
        guard slotEnergies.count == code.slots.count else { return 0 }
        let on = zip(slotEnergies, code.slots).filter { $0.1 }.map { $0.0 }
        let off = zip(slotEnergies, code.slots).filter { !$0.1 }.map { $0.0 }
        guard !on.isEmpty, !off.isEmpty else { return 0 }
        let onMean = on.reduce(0, +) / Double(on.count)
        let offMean = off.reduce(0, +) / Double(off.count)
        return (onMean - offMean) / (offMean + 1e-9)
    }

    /// BOTH channels must correlate for an auto-pass (fusion AND) — mic gives sensitivity,
    /// magnetometer makes acoustic/shake spoofing impossible. Thresholds are on-device-tunable.
    static func passes(micScore: Double, magScore: Double,
                       micThreshold: Double = 1.0, magThreshold: Double = 0.25) -> Bool {
        micScore >= micThreshold && magScore >= magThreshold
    }
}
