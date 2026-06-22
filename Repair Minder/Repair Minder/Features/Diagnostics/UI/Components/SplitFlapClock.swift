// Features/Diagnostics/UI/Components/SplitFlapClock.swift
// A train-station split-flap countdown clock for the Battery Drain test.
// Displays MM:SS with each digit animating independently on change.
import SwiftUI

// MARK: - Public entry point

/// Displays `secondsRemaining` as a `MM:SS` split-flap departure-board clock.
/// Each digit flips with a 3D rotation when its value changes.
struct SplitFlapClock: View {
    let secondsRemaining: Int

    private var mm: String { String(format: "%02d", max(0, secondsRemaining) / 60) }
    private var ss: String { String(format: "%02d", max(0, secondsRemaining) % 60) }

    var body: some View {
        HStack(spacing: 6) {
            FlapDigit(char: mm.first.map(String.init) ?? "0")
            FlapDigit(char: mm.last.map(String.init) ?? "0")

            // Separator colon — blinks each second
            Text(":")
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(secondsRemaining % 2 == 0 ? 1.0 : 0.35))
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.25), value: secondsRemaining % 2)

            FlapDigit(char: ss.first.map(String.init) ?? "0")
            FlapDigit(char: ss.last.map(String.init) ?? "0")
        }
    }
}

// MARK: - Single digit tile

/// One split-flap tile. Plays a Y-axis 3D flip when `char` changes.
private struct FlapDigit: View {
    let char: String

    // Drive the flip animation: each value change increments this counter which
    // maps to 0° (front visible) → -90° (edge) → 0° (new face visible).
    @State private var flipDegrees: Double = 0
    @State private var displayedChar: String = ""

    var body: some View {
        ZStack {
            // Tile background (dark capsule)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.72))
                .frame(width: 52, height: 68)

            // Centre score line
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(width: 52, height: 1.5)

            Text(displayedChar)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .rotation3DEffect(
                    .degrees(flipDegrees),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.6
                )
        }
        .frame(width: 52, height: 68)
        .onAppear {
            displayedChar = char
        }
        .onChange(of: char) { _, newChar in
            // Phase 1: flip to edge (disappear), swap text, flip back to face
            withAnimation(.easeIn(duration: 0.14)) {
                flipDegrees = -90
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                displayedChar = newChar
                withAnimation(.easeOut(duration: 0.14)) {
                    flipDegrees = 0
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            SplitFlapClock(secondsRemaining: 600)
            SplitFlapClock(secondsRemaining: 327)
            SplitFlapClock(secondsRemaining: 0)
        }
    }
}
