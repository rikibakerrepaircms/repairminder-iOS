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

    /// Auto-pass when the microphone band-energy correlates strongly with the SECRET, per-run coded
    /// buzz. Correlation against a random ON/OFF code the device only knows at runtime IS the
    /// anti-spoof: ambient noise is uncorrelated (averages out), a steady tone raises ON and OFF
    /// slots equally (cancels in the score), and a replay can't match a code it can't predict. The
    /// old magnetometer channel was removed — it physically cannot sample the ~230 Hz Taptic carrier
    /// (magnetometer is ~50 Hz + low-passed) and reads 0 on a still phone; see
    /// docs/plans/device-diagnostics/33-vibration-detection-research.md. The stillness veto (isStill)
    /// now carries the anti-shake defence. Threshold is on-device-tunable: a real buzz scores ~3+,
    /// flat noise <0.2, so 1.0 sits with wide margin above noise while tolerating per-cycle variance.
    static func passes(micScore: Double, micThreshold: Double = 1.0) -> Bool {
        micScore >= micThreshold
    }

    /// Stillness veto: a cycle only counts if the phone was resting still. A genuine buzz barely
    /// moves user-acceleration (~0.05 g); shaking/handling spikes it. Disqualifying moving cycles is
    /// the real anti-spoof — it stops "shake the phone" from faking the mic/mag correlation.
    /// `motionLevel` is the mean user-acceleration magnitude (g) over the cycle. Tunable.
    static func isStill(motionLevel: Double, threshold: Double = 0.08) -> Bool {
        motionLevel < threshold
    }
}
