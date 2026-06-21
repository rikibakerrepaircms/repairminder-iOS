// Features/Diagnostics/Tests/SensorsTests.swift
// Sensors category: Accelerometer, Gyroscope, Magnetic (compass), Proximity, Light, GPS.
import SwiftUI
#if os(iOS)
import AVFoundation
#endif

struct AccelerometerTest: DiagnosticTest {
    let id = "accelerometer"; let name = "Accelerometer"; let category: TestCategory = .sensors
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(AccelerometerTestView(complete: complete)) }
    // No preflight auto-pass (I1): a brief liveness sample is too weak to certify the sensor, so it
    // must run the interactive tilt test. The protocol default preflight() returns nil.
    #else
    var isSupported: Bool { false }
    #endif
}

struct GyroscopeTest: DiagnosticTest {
    let id = "gyroscope"; let name = "Gyroscope"; let category: TestCategory = .sensors
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(GyroscopeTestView(complete: complete)) }
    // No preflight auto-pass (I1): a brief liveness sample is too weak to certify the sensor, so it
    // must run the interactive axis-rotation test. The protocol default preflight() returns nil.
    #else
    var isSupported: Bool { false }
    #endif
}

struct MagneticTest: DiagnosticTest {
    let id = "magnetic"; let name = "Magnetic Sensor"; let category: TestCategory = .sensors
    var requiredPermissions: [DiagnosticPermission] { [.location] }
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(MagneticTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

struct ProximityTest: DiagnosticTest {
    let id = "proximity"; let name = "Proximity Sensor"; let category: TestCategory = .sensors
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(ProximityTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

struct LightSensorTest: DiagnosticTest {
    let id = "light"; let name = "Light Sensor"; let category: TestCategory = .sensors
    var requiredPermissions: [DiagnosticPermission] { [.camera] }
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front).devices.first != nil
    }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(LightSensorTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

struct GPSTest: DiagnosticTest {
    let id = "gps"; let name = "GPS"; let category: TestCategory = .sensors
    var requiredPermissions: [DiagnosticPermission] { [.location] }
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(GPSTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

#if os(iOS)
import CoreMotion
import CoreLocation
import UIKit

// MARK: Accelerometer — tilt to hit all 4 edges (gravity)

@MainActor private final class MotionCoordinator: ObservableObject {
    private let mm = CMMotionManager()
    @Published var gravity: CGVector = .zero
    @Published var rotationMax: (x: Double, y: Double, z: Double) = (0, 0, 0)

    func startGravity() {
        guard mm.isDeviceMotionAvailable else { return }
        mm.deviceMotionUpdateInterval = 1.0 / 30.0
        mm.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let g = motion?.gravity else { return }
            self?.gravity = CGVector(dx: g.x, dy: g.y)
        }
    }
    func startGyro() {
        guard mm.isGyroAvailable else { return }
        mm.gyroUpdateInterval = 1.0 / 30.0
        mm.startGyroUpdates(to: .main) { [weak self] data, _ in
            guard let r = data?.rotationRate, let self else { return }
            self.rotationMax = (max(self.rotationMax.x, abs(r.x)),
                                max(self.rotationMax.y, abs(r.y)),
                                max(self.rotationMax.z, abs(r.z)))
        }
    }
    func stop() { mm.stopDeviceMotionUpdates(); mm.stopGyroUpdates() }
}

private struct AccelerometerTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var motion = MotionCoordinator()
    @State private var hit: Set<String> = []   // left/right/up/down

    var body: some View {
        TestScaffold(
            title: "Accelerometer",
            instruction: "Tilt the device left, right, up and down. Each edge turns green when reached. All four = pass.",
            hints: ["Hold the device and tilt it in all 4 directions"],
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            GeometryReader { geo in
                // Map gravity (≈0 flat → ±1 on edge) to the full play area so the ball reaches every
                // wall. At |g| ≈ 0.7 (well below the 0.6 mark threshold isn't quite reached) the ball
                // touches the wall; clamp so it pins to the edge rather than overshooting.
                let ballR: CGFloat = 14
                let pad: CGFloat = 6
                let travelX = max(0, geo.size.width / 2 - ballR - pad)
                let travelY = max(0, geo.size.height / 2 - ballR - pad)
                let dx = clampOffset(motion.gravity.dx, travel: travelX)
                let dy = clampOffset(motion.gravity.dy, travel: travelY)
                ZStack {
                    edge("up", aligned: .top); edge("down", aligned: .bottom)
                    edge("left", aligned: .leading); edge("right", aligned: .trailing)
                    Circle().fill(Color.accentColor).frame(width: ballR * 2, height: ballR * 2)
                        .offset(x: dx, y: dy)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(height: 260)
            .background(Color.platformGray6)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear { motion.startGravity() }
            .onChange(of: motion.gravity.dx) { _, x in if x < -0.6 { mark("left") }; if x > 0.6 { mark("right") } }
            .onChange(of: motion.gravity.dy) { _, y in if y < -0.6 { mark("up") }; if y > 0.6 { mark("down") } }
        }
    }
    private func edge(_ key: String, aligned: Alignment) -> some View {
        RoundedRectangle(cornerRadius: 4).fill(hit.contains(key) ? Color.green : Color.platformGray4)
            .frame(width: aligned == .leading || aligned == .trailing ? 8 : 80,
                   height: aligned == .top || aligned == .bottom ? 8 : 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: aligned).padding(6)
    }
    private func mark(_ k: String) {
        hit.insert(k)
        if hit.count == 4 { finish(.pass, ["edges": "4"]) }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) { motion.stop(); complete(diagnosticOutcome("accelerometer", "Accelerometer", s, d)) }
}

/// Maps a gravity component to a pixel offset that reaches `travel` (the wall) by the time the
/// tilt hits the 0.6 mark threshold, clamped so the ball pins to the edge instead of overshooting.
private func clampOffset(_ g: CGFloat, travel: CGFloat) -> CGFloat {
    let scaled = g / 0.6 * travel
    return max(-travel, min(travel, scaled))
}

private struct GyroscopeTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var motion = MotionCoordinator()

    var body: some View {
        TestScaffold(
            title: "Gyroscope",
            instruction: "Rotate the device around all three axes (pitch, roll, yaw). It passes when rotation is detected on every axis.",
            hints: ["Perform all rotation movements"],
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            VStack(spacing: 6) {
                axis("Pitch (x)", motion.rotationMax.x)
                axis("Roll (y)", motion.rotationMax.y)
                axis("Yaw (z)", motion.rotationMax.z)
            }
            .onAppear { motion.startGyro() }
            .onChange(of: motion.rotationMax.z) { _, _ in
                let r = motion.rotationMax
                if r.x > 2, r.y > 2, r.z > 2 { finish(.pass, ["axes": "3"]) }
            }
        }
    }
    private func axis(_ label: String, _ v: Double) -> some View {
        HStack { Text(label); Spacer(); Text(String(format: "%.1f", v)).foregroundStyle(v > 2 ? .green : .secondary) }
            .font(.subheadline).padding(8).background(Color.platformGray6).clipShape(RoundedRectangle(cornerRadius: 8))
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) { motion.stop(); complete(diagnosticOutcome("gyroscope", "Gyroscope", s, d)) }
}

// MARK: Compass / GPS via CLLocationManager

@MainActor private final class LocationCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let lm = CLLocationManager()
    @Published var heading: Double = 0
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var denied = false
    /// 10°-wide buckets (0…35) seen so far during the sweep.
    @Published var sweptSectors = Set<Int>()

    override init() { super.init(); lm.delegate = self }
    func startHeading() { lm.startUpdatingHeading() }
    func startLocation() { lm.requestWhenInUseAuthorization(); lm.startUpdatingLocation() }
    func stop() { lm.stopUpdatingHeading(); lm.stopUpdatingLocation() }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        guard h.magneticHeading >= 0 else { return }   // <0 == invalid/uncalibrated
        Task { @MainActor in
            self.heading = h.magneticHeading
            self.sweptSectors.insert(Int(h.magneticHeading / 10) % 36)
        }
    }
    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let c = locs.last?.coordinate else { return }
        Task { @MainActor in self.coordinate = c }
    }
    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}
    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        Task { @MainActor in if m.authorizationStatus == .denied || m.authorizationStatus == .restricted { self.denied = true } }
    }
}

private struct MagneticTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var loc = LocationCoordinator()

    var body: some View {
        TestScaffold(
            title: "Magnetic Sensor",
            instruction: "Hold the device flat and rotate slowly through a full circle. Each 10° segment turns green as the compass passes through it — all 36 green = pass.",
            hints: ["Rotate slowly in a circle while horizontal"],
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            VStack(spacing: 14) {
                ZStack {
                    // 36 segments, one per 10°. Grey until the heading sweeps through that angle.
                    ForEach(0..<36, id: \.self) { i in
                        Capsule()
                            .fill(loc.sweptSectors.contains(i) ? Color.green : Color.platformGray4)
                            .frame(width: 6, height: 20)
                            .offset(y: -96)
                            .rotationEffect(.degrees(Double(i) * 10))
                    }
                    // Live heading needle.
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                        .rotationEffect(.degrees(loc.heading))
                    Text("\(Int(loc.heading))°")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .offset(y: 40)
                }
                .frame(width: 220, height: 220)
                Text("\(loc.sweptSectors.count)/36 segments")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(loc.sweptSectors.count >= 36 ? .green : .secondary)
            }
            .onAppear { loc.startHeading() }
            .onChange(of: loc.sweptSectors.count) { _, n in if n >= 36 { finish(.pass, ["sectors": "\(n)"]) } }
        }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) { loc.stop(); complete(diagnosticOutcome("magnetic", "Magnetic Sensor", s, d)) }
}

private struct GPSTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var loc = LocationCoordinator()

    var body: some View {
        TestScaffold(
            title: "GPS",
            instruction: "Acquiring your location. It passes automatically once a GPS fix is obtained.",
            hints: ["Make sure Location is allowed and you have signal"],
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            VStack(spacing: 8) {
                if let c = loc.coordinate {
                    Image(systemName: "mappin.circle.fill").font(.system(size: 44)).foregroundStyle(.green)
                    Text(String(format: "%.5f, %.5f", c.latitude, c.longitude)).font(.subheadline.monospacedDigit())
                } else if loc.denied {
                    Label("Location permission denied", systemImage: "xmark.circle").foregroundStyle(.red)
                } else {
                    ProgressView(); Text("Locating…").font(.caption).foregroundStyle(.secondary)
                }
            }
            .onAppear { loc.startLocation() }
            .onChange(of: loc.coordinate?.latitude) { _, lat in
                if let c = loc.coordinate { finish(.pass, ["lat": String(format: "%.5f", c.latitude), "lng": String(format: "%.5f", c.longitude)]) }
                _ = lat
            }
        }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) { loc.stop(); complete(diagnosticOutcome("gps", "GPS", s, d)) }
}

// MARK: Proximity

private struct ProximityTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var covered = false
    @State private var observer: NSObjectProtocol?
    @State private var done = false

    var body: some View {
        TestScaffold(
            title: "Proximity Sensor",
            instruction: "Cover the top-front of the device, then take your hand away. It passes when the sensor sees both.",
            hints: ["Move your hand over the top-front of the device, then remove it"],
            onPass: { finish(.pass) }, onFail: { finish(.fail) }, onSkip: { finish(.skip) }
        ) {
            VStack(spacing: 8) {
                Image(systemName: covered ? "hand.raised.fill" : "hand.raised")
                    .font(.system(size: 44)).foregroundStyle(covered ? .green : .secondary)
                Text(covered ? "Detected — now remove your hand" : "Waiting…").font(.caption).foregroundStyle(.secondary)
            }
            .onAppear {
                UIDevice.current.isProximityMonitoringEnabled = true
                observer = NotificationCenter.default.addObserver(forName: UIDevice.proximityStateDidChangeNotification, object: nil, queue: .main) { _ in
                    if UIDevice.current.proximityState {
                        covered = true
                    } else if covered {
                        finish(.pass, ["proximity": "1"])
                    }
                }
            }
            .onDisappear {
                UIDevice.current.isProximityMonitoringEnabled = false
                removeObserver()
            }
        }
    }
    private func removeObserver() {
        if let obs = observer { NotificationCenter.default.removeObserver(obs); observer = nil }
    }
    private func finish(_ s: TestStatus, _ d: [String: String]? = nil) {
        guard !done else { return }
        done = true
        UIDevice.current.isProximityMonitoringEnabled = false
        removeObserver()
        complete(diagnosticOutcome("proximity", "Proximity Sensor", s, d))
    }
}

// MARK: Light — front-camera luminance proxy (no public ALS API)

/// Drives auto-pass logic for the light sensor test using a LuminanceProbe.
/// Collects 10 samples as a baseline, then passes automatically on a ≥25% luminance jump.
@MainActor final class LightViewModel: ObservableObject {
    private let probe: LuminanceProbe
    @Published var baseline: Double = 0
    @Published var current: Double = 0
    @Published var outcome: TestOutcome?
    private var samples: [Double] = []
    private var baselineSet = false

    init(probe: LuminanceProbe) { self.probe = probe }

    func start() {
        probe.start(onSample: { [weak self] v in
            guard let self else { return }
            self.current = v
            if !self.baselineSet {
                self.samples.append(v)
                if self.samples.count >= 10 {
                    self.baseline = self.samples.reduce(0, +) / Double(self.samples.count)
                    self.baselineSet = true
                }
            } else if self.outcome == nil,
                      LightGate.passes(baseline: self.baseline, peak: v, thresholdPct: 25, minAbsoluteDelta: 30) {
                let delta = (v - self.baseline) / self.baseline * 100
                self.outcome = diagnosticOutcome("light", "Light Sensor", .pass, [
                    "lux_baseline": String(format: "%.0f", self.baseline),
                    "lux_peak": String(format: "%.0f", v),
                    "delta_pct": String(format: "%.0f", delta),
                ])
                self.probe.stop()
            }
        })
    }

    func fail() { probe.stop(); outcome = diagnosticOutcome("light", "Light Sensor", .fail, nil) }
    func skip() { probe.stop(); outcome = diagnosticOutcome("light", "Light Sensor", .skip, nil) }
}

private struct LightSensorTestView: View {
    let complete: (TestOutcome) -> Void
    private let probe: CameraProbe?

    init(complete: @escaping (TestOutcome) -> Void) {
        self.complete = complete
        self.probe = CameraProbe.front().map { CameraProbe(device: $0) }
    }

    var body: some View {
        if let probe {
            LightSensorActiveView(probe: probe, complete: complete)
        } else {
            Color.clear.onAppear {
                complete(diagnosticOutcome("light", "Light Sensor", .skip, ["reason": "no_front_camera"]))
            }
        }
    }
}

private struct LightSensorActiveView: View {
    let complete: (TestOutcome) -> Void
    private let probe: CameraProbe
    @StateObject private var model: LightViewModel
    @State private var savedBrightness: CGFloat = UIScreen.main.brightness
    /// The test runs in two phases: an intro shown at normal brightness (so the tech can read the
    /// instructions and get a torch ready), then the measuring phase which dims the screen so the
    /// front camera has a dark baseline to detect a light increase against. Without this, the screen
    /// dimmed to black the instant the page opened, which read as the test being broken.
    @State private var started = false

    init(probe: CameraProbe, complete: @escaping (TestOutcome) -> Void) {
        self.complete = complete
        self.probe = probe
        _model = StateObject(wrappedValue: LightViewModel(probe: probe))
    }

    var body: some View {
        TestScaffold(
            title: "Light Sensor",
            instruction: started
                ? "Screen dimmed. Shine a torch at the top-front of the device — it passes automatically when the front sensor sees the light increase."
                : "Get a torch ready. When you tap Start, the screen dims and the front sensor watches for a light increase.",
            hints: started
                ? ["Point a torch at the top of the screen (front side)", "Keep it steady until the bar jumps"]
                : ["The screen will go dark on purpose — that's expected", "Shine a torch at the top-front to make the bar move"],
            allowManualPass: false,
            onPass: {},
            onFail: { model.fail() },
            onSkip: { model.skip() }
        ) {
            VStack(spacing: 16) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(model.outcome?.status == .pass ? .green : .yellow)

                if !started {
                    // Intro — normal brightness, explain what's about to happen.
                    Text("The screen will dim while the front camera measures light. Shine a torch at the top-front of the device to pass.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Start") { beginMeasuring() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("light-start")
                } else if model.baseline > 0 {
                    // Live luminance bar relative to baseline
                    let ratio = min(model.current / (model.baseline * 2), 1.0)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6).fill(Color.platformGray6)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ratio >= 0.625 ? Color.green : Color.accentColor)
                                .frame(width: geo.size.width * ratio)
                        }
                    }
                    .frame(height: 20)
                    .padding(.horizontal)

                    Text(String(format: "Baseline %.0f  ·  Current %.0f", model.baseline, model.current))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Measuring baseline…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            savedBrightness = UIScreen.main.brightness
        }
        .onDisappear {
            UIScreen.main.brightness = savedBrightness
            probe.stop()
        }
        .onChange(of: model.outcome?.status) { _, _ in
            if let o = model.outcome {
                UIScreen.main.brightness = savedBrightness
                complete(o)
            }
        }
    }

    private func beginMeasuring() {
        started = true
        savedBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 0
        model.start()
    }
}
#endif
