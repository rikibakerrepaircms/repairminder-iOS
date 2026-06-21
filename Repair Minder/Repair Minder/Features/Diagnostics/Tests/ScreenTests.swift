// Features/Diagnostics/Tests/ScreenTests.swift
// Screen category: Touchscreen, Dead Pixel, Multitouch, 3D Touch, Stylus.
// Interactive; iOS-only hardware (guarded so the Mac target still compiles → reported unsupported).
import SwiftUI

/// Pure 3D-Touch decision: a press is "firm" when the measured force exceeds half of the touch's
/// maximum possible force. Ratio-based so it works across hardware; `maxPossible <= 0` (no
/// force-touch) can never pass.
enum ForceTouchGate {
    static func firm(force: Double, maxPossible: Double) -> Bool {
        guard maxPossible > 0 else { return false }
        return force / maxPossible > 0.5
    }
}

// MARK: - Touchscreen

struct TouchscreenTest: DiagnosticTest {
    let id = "touchscreen"
    let name = "Touchscreen"
    let category: TestCategory = .screen
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? {
        AnyView(TouchscreenTestView(complete: complete))
    }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - Dead Pixel (colour cycle)

struct DeadPixelTest: DiagnosticTest {
    let id = "color"
    let name = "Dead Pixel"
    let category: TestCategory = .screen
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? {
        AnyView(DeadPixelTestView(complete: complete))
    }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - Multitouch

struct MultitouchTest: DiagnosticTest {
    let id = "multitouch"
    let name = "Multitouch"
    let category: TestCategory = .screen
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? {
        AnyView(MultitouchTestView(complete: complete))
    }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - 3D Touch

struct ThreeDTouchTest: DiagnosticTest {
    let id = "touch3d"
    let name = "3D Touch"
    let category: TestCategory = .screen
    let requiresInteraction = true
    #if os(iOS)
    @MainActor var isSupported: Bool {
        #if os(iOS)
        // Force Touch removed since iPhone XR; absent → engine records skip.
        return UIScreen.main.traitCollection.forceTouchCapability == .available
        #else
        return false
        #endif
    }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? {
        AnyView(ForceTouchTestView(complete: complete))
    }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - Stylus

struct StylusTest: DiagnosticTest {
    let id = "pen"
    let name = "Stylus Pen"
    let category: TestCategory = .screen
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? {
        AnyView(StylusTestView(complete: complete))
    }
    #else
    var isSupported: Bool { false }
    #endif
}

#if os(iOS)
import UIKit

// MARK: Touchscreen view (SwiftUI grid; touch all cells → pass)

/// Immersive full-screen touch grid. The top instruction and bottom controls hide while the
/// user is touching so the WHOLE screen can be swept; fine cells (~16pt) catch small dead spots.
/// Drawn with Canvas (≈1500 cells) and drag-path interpolation so fast sweeps don't skip cells.
private struct TouchscreenTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var touched: Set<Int> = []
    @State private var started = false
    @State private var dragging = false
    @State private var lastLocation: CGPoint?

    private let target: CGFloat = 21   // cell size (bumped ~30% from 16 for easier sweeping)

    var body: some View {
        GeometryReader { geo in
            let cols = max(8, Int(geo.size.width / target))
            let rows = max(12, Int(geo.size.height / target))
            let w = geo.size.width / CGFloat(cols)
            let h = geo.size.height / CGFloat(rows)
            let total = cols * rows

            ZStack(alignment: .top) {
                Canvas { ctx, _ in
                    for i in 0..<total {
                        let r = i / cols, c = i % cols
                        let rect = CGRect(x: CGFloat(c) * w, y: CGFloat(r) * h, width: w - 1, height: h - 1)
                        ctx.fill(Path(rect), with: .color(touched.contains(i) ? .green : Color(.systemGray4)))
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            started = true
                            dragging = true
                            mark(from: lastLocation ?? v.location, to: v.location,
                                 w: w, h: h, cols: cols, rows: rows, total: total)
                            lastLocation = v.location
                        }
                        .onEnded { _ in dragging = false; lastLocation = nil }
                )

                if !started {
                    VStack(spacing: 4) {
                        Text("Touchscreen").font(.headline)
                        Text("Drag across the whole screen — every cell turns green. Any cell that won't is a dead spot.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(12).frame(maxWidth: .infinity).background(.ultraThinMaterial)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if !dragging {
                    VStack(spacing: 10) {
                        Text("\(Int((total > 0 ? Double(touched.count) / Double(total) : 0) * 100))% covered")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            DiagnosticActionButton("Skip", color: .gray, id: "test-skip") {
                                complete(diagnosticOutcome("touchscreen", "Touchscreen", .skip))
                            }
                            DiagnosticActionButton("Fail", color: .red, id: "test-fail") {
                                complete(diagnosticOutcome("touchscreen", "Touchscreen", .fail))
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12).background(.ultraThinMaterial)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: started)
            .animation(.easeInOut(duration: 0.15), value: dragging)
        }
        .ignoresSafeArea()
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    /// Mark every cell along the segment from→to (interpolated) so fast drags fill continuously.
    private func mark(from: CGPoint, to: CGPoint, w: CGFloat, h: CGFloat, cols: Int, rows: Int, total: Int) {
        let dx = to.x - from.x, dy = to.y - from.y
        let steps = max(1, Int(max(abs(dx), abs(dy)) / (min(w, h) / 2)))
        var changed = false
        for s in 0...steps {
            let t = steps == 0 ? 0 : CGFloat(s) / CGFloat(steps)
            let x = from.x + dx * t, y = from.y + dy * t
            let c = Int(x / w), r = Int(y / h)
            if c >= 0, c < cols, r >= 0, r < rows, touched.insert(r * cols + c).inserted { changed = true }
        }
        if changed, touched.count == total {
            complete(diagnosticOutcome("touchscreen", "Touchscreen", .pass, ["cells": "\(total)"]))
        }
    }
}

// MARK: Dead Pixel view (colour cycle)

/// True full-screen colour cycle: the solid colour fills the entire display edge-to-edge (under the
/// status bar and home indicator) so the whole panel can be inspected. Tap the colour to advance;
/// a translucent control strip floats over the bottom with the colour name + Pass/Fail/Skip.
private struct DeadPixelTestView: View {
    let complete: (TestOutcome) -> Void
    private let colors: [(String, Color)] = [("Red", .red), ("Green", .green), ("Blue", .blue),
                                             ("White", .white), ("Black", .black), ("Grey", .gray)]
    @State private var index = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            colors[index].1
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { index = (index + 1) % colors.count }

            VStack(spacing: 10) {
                Text("\(colors[index].0)  ·  \(index + 1)/\(colors.count)")
                    .font(.subheadline.bold())
                Text("Tap anywhere to change colour. Look for stuck or dead pixels on each.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    DiagnosticActionButton("Skip", color: .gray, id: "test-skip") {
                        complete(diagnosticOutcome("color", "Dead Pixel", .skip))
                    }
                    DiagnosticActionButton("Fail", color: .red, id: "test-fail") {
                        complete(diagnosticOutcome("color", "Dead Pixel", .fail))
                    }
                    DiagnosticActionButton("Pass", color: .green, id: "test-pass") {
                        complete(diagnosticOutcome("color", "Dead Pixel", .pass))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(edges: .top)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}

// MARK: UIKit touch capture (multitouch / force / stylus)

private struct TouchCaptureView: UIViewRepresentable {
    var onUpdate: (_ activeTouches: Int, _ maxForce: CGFloat, _ maxPossibleForce: CGFloat, _ pencil: Bool, _ locations: [CGPoint]) -> Void
    func makeUIView(context: Context) -> CaptureView { let v = CaptureView(); v.onUpdate = onUpdate; return v }
    func updateUIView(_ uiView: CaptureView, context: Context) {}

    final class CaptureView: UIView {
        var onUpdate: ((Int, CGFloat, CGFloat, Bool, [CGPoint]) -> Void)?
        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            backgroundColor = UIColor.secondarySystemBackground
            layer.cornerRadius = 12
        }
        required init?(coder: NSCoder) { fatalError() }
        private func report(_ event: UIEvent?) {
            let touches = (event?.allTouches ?? []).filter { $0.phase != .ended && $0.phase != .cancelled }
            let force = touches.map { $0.force }.max() ?? 0
            let maxPossible = touches.map { $0.maximumPossibleForce }.max() ?? 0
            let pencil = touches.contains { $0.type == .pencil }
            let locations = touches.map { $0.location(in: self) }
            onUpdate?(touches.count, force, maxPossible, pencil, locations)
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
    }
}

// MARK: Multitouch view

private struct MultitouchTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var maxTouches = 0
    @State private var points: [CGPoint] = []
    @State private var passed = false   // guard: TouchCaptureView fires continuously while fingers are down

    var body: some View {
        TestScaffold(
            title: "Multitouch",
            instruction: "Touch the screen with two or more fingers at once.",
            hints: ["Touch with 2+ fingers at the same time"],
            allowManualPass: false,
            fullBleed: true,
            onPass: { complete(diagnosticOutcome("multitouch", "Multitouch", .pass, ["max_touches": "\(maxTouches)"])) },
            onFail: { complete(diagnosticOutcome("multitouch", "Multitouch", .fail, ["max_touches": "\(maxTouches)"])) },
            onSkip: { complete(diagnosticOutcome("multitouch", "Multitouch", .skip)) }
        ) {
            GeometryReader { geo in
                ZStack {
                    // Touch capture fills the full area
                    TouchCaptureView { count, _, _, _, locs in
                        points = locs
                        if count > maxTouches { maxTouches = count }
                        if maxTouches >= 2 && !passed {
                            passed = true
                            complete(diagnosticOutcome("multitouch", "Multitouch", .pass, ["max_touches": "\(maxTouches)"]))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))

                    // Visible touch indicators
                    ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                        Circle()
                            .fill(Color.accentColor.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .position(pt)
                    }

                    // Floating pill at top showing touch count
                    VStack {
                        Text("\(maxTouches) simultaneous touches")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.top, 12)
                        Spacer()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

// MARK: 3D Touch view

private struct ForceTouchTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var maxForce: CGFloat = 0

    var body: some View {
        TestScaffold(
            title: "3D Touch",
            instruction: "Press firmly on the panel. The pressure reading rises with force; pass when firm pressure registers.",
            hints: ["Tap and apply pressure anywhere on the panel"],
            fullBleed: true,
            onPass: { complete(diagnosticOutcome("touch3d", "3D Touch", .pass, ["max_force": String(format: "%.2f", maxForce)])) },
            onFail: { complete(diagnosticOutcome("touch3d", "3D Touch", .fail)) },
            onSkip: { complete(diagnosticOutcome("touch3d", "3D Touch", .skip)) }
        ) {
            ZStack(alignment: .top) {
                TouchCaptureView { _, force, maxPossible, _, _ in
                    if force > maxForce { maxForce = force }
                    if ForceTouchGate.firm(force: Double(force), maxPossible: Double(maxPossible)) {
                        complete(diagnosticOutcome("touch3d", "3D Touch", .pass, ["max_force": String(format: "%.2f", maxForce)]))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 4) {
                    Text(String(format: "%.2f", maxForce)).font(.system(size: 44, weight: .bold))
                    Text("max pressure").font(.caption).foregroundStyle(.secondary)
                }
                .padding(10).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.top, 12)
            }
        }
    }
}

// MARK: Stylus view

private struct StylusTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var pencilSeen = false

    var body: some View {
        TestScaffold(
            title: "Stylus Pen",
            instruction: "Draw on the panel with an Apple Pencil / stylus. It passes when stylus input is detected.",
            hints: ["Use the stylus, not your finger"],
            fullBleed: true,
            onPass: { complete(diagnosticOutcome("pen", "Stylus Pen", .pass)) },
            onFail: { complete(diagnosticOutcome("pen", "Stylus Pen", .fail)) },
            onSkip: { complete(diagnosticOutcome("pen", "Stylus Pen", .skip)) }
        ) {
            ZStack(alignment: .top) {
                TouchCaptureView { _, _, _, pencil, _ in
                    if pencil {
                        pencilSeen = true
                        complete(diagnosticOutcome("pen", "Stylus Pen", .pass))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 4) {
                    Image(systemName: pencilSeen ? "checkmark.circle.fill" : "applepencil")
                        .font(.system(size: 44))
                        .foregroundStyle(pencilSeen ? .green : .secondary)
                    Text(pencilSeen ? "Stylus detected" : "Waiting for stylus…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(10).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.top, 12)
            }
        }
    }
}
#endif
