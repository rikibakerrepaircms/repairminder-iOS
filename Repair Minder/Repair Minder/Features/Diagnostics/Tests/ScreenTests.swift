// Features/Diagnostics/Tests/ScreenTests.swift
// Screen category: Touchscreen, Dead Pixel, Multitouch, 3D Touch, Stylus.
// Interactive; iOS-only hardware (guarded so the Mac target still compiles → reported unsupported).
import SwiftUI

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
    var isSupported: Bool { true }
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

private struct TouchscreenTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var touched: Set<Int> = []

    var body: some View {
        TestScaffold(
            title: "Touchscreen",
            instruction: "Touch every box. Each turns green when registered — any box that won't turn green is a dead spot.",
            hints: ["Drag across all boxes to complete the test"],
            fullBleed: true,
            onPass: { complete(diagnosticOutcome("touchscreen", "Touchscreen", .pass)) },
            onFail: { complete(diagnosticOutcome("touchscreen", "Touchscreen", .fail)) },
            onSkip: { complete(diagnosticOutcome("touchscreen", "Touchscreen", .skip)) }
        ) {
            GeometryReader { geo in
                let target: CGFloat = 60
                let cols = max(4, Int(geo.size.width / target))
                let rows = max(6, Int(geo.size.height / target))
                let w = geo.size.width / CGFloat(cols)
                let h = geo.size.height / CGFloat(rows)
                let total = cols * rows
                ZStack {
                    ForEach(0..<total, id: \.self) { i in
                        let r = i / cols, c = i % cols
                        Rectangle()
                            .fill(touched.contains(i) ? Color.green : Color.platformGray5)
                            .border(Color.platformGray4)
                            .frame(width: w, height: h)
                            .position(x: (CGFloat(c) + 0.5) * w, y: (CGFloat(r) + 0.5) * h)
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let c = Int(value.location.x / w), r = Int(value.location.y / h)
                    if c >= 0, c < cols, r >= 0, r < rows {
                        touched.insert(r * cols + c)
                        if touched.count == total {
                            complete(diagnosticOutcome("touchscreen", "Touchscreen", .pass, ["cells": "\(total)"]))
                        }
                    }
                })
            }
        }
    }
}

// MARK: Dead Pixel view (colour cycle)

private struct DeadPixelTestView: View {
    let complete: (TestOutcome) -> Void
    private let colors: [(String, Color)] = [("Red", .red), ("Green", .green), ("Blue", .blue),
                                             ("White", .white), ("Black", .black), ("Grey", .gray)]
    @State private var index = 0

    var body: some View {
        TestScaffold(
            title: "Dead Pixel",
            instruction: "Tap the swatch to cycle solid colours. Look for any pixels stuck a different colour or black spots.",
            hints: ["Tap the colour to change it", "Inspect the whole screen on each colour"],
            allowManualPass: true,   // subjective: user judges for dead pixels
            fullBleed: true,
            onPass: { complete(diagnosticOutcome("color", "Dead Pixel", .pass)) },
            onFail: { complete(diagnosticOutcome("color", "Dead Pixel", .fail)) },
            onSkip: { complete(diagnosticOutcome("color", "Dead Pixel", .skip)) }
        ) {
            ZStack(alignment: .top) {
                colors[index].1
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { index = (index + 1) % colors.count }
                Text(colors[index].0)
                    .font(.caption).padding(8).background(.ultraThinMaterial)
                    .clipShape(Capsule()).padding(.top, 12)
            }
        }
    }
}

// MARK: UIKit touch capture (multitouch / force / stylus)

private struct TouchCaptureView: UIViewRepresentable {
    var onUpdate: (_ activeTouches: Int, _ maxForce: CGFloat, _ pencil: Bool) -> Void
    func makeUIView(context: Context) -> CaptureView { let v = CaptureView(); v.onUpdate = onUpdate; return v }
    func updateUIView(_ uiView: CaptureView, context: Context) {}

    final class CaptureView: UIView {
        var onUpdate: ((Int, CGFloat, Bool) -> Void)?
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
            let pencil = touches.contains { $0.type == .pencil }
            onUpdate?(touches.count, force, pencil)
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

    var body: some View {
        TestScaffold(
            title: "Multitouch",
            instruction: "Touch the panel with two or more fingers at once. The highest number of simultaneous touches is shown.",
            hints: ["Touch with 2+ fingers at the same time"],
            fullBleed: true,
            onPass: { complete(diagnosticOutcome("multitouch", "Multitouch", .pass, ["max_touches": "\(maxTouches)"])) },
            onFail: { complete(diagnosticOutcome("multitouch", "Multitouch", .fail, ["max_touches": "\(maxTouches)"])) },
            onSkip: { complete(diagnosticOutcome("multitouch", "Multitouch", .skip)) }
        ) {
            ZStack(alignment: .top) {
                TouchCaptureView { count, _, _ in
                    if count > maxTouches { maxTouches = count }
                    if maxTouches >= 2 {
                        complete(diagnosticOutcome("multitouch", "Multitouch", .pass, ["max_touches": "\(maxTouches)"]))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 4) {
                    Text("\(maxTouches)").font(.system(size: 48, weight: .bold))
                    Text("simultaneous touches").font(.caption).foregroundStyle(.secondary)
                }
                .padding(10).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.top, 12)
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
                TouchCaptureView { _, force, _ in
                    if force > maxForce { maxForce = force }
                    if maxForce > 1.5 {
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
                TouchCaptureView { _, _, pencil in
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
