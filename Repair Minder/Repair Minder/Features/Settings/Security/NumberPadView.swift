//
//  NumberPadView.swift
//  Repair Minder
//
//  Created on 05/02/2026.
//

import SwiftUI

struct NumberPadView: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    private let buttons: [[NumberPadButton]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.empty,      .digit("0"), .delete]
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(buttons.indices, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(buttons[row].indices, id: \.self) { col in
                        numberPadButton(buttons[row][col])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func numberPadButton(_ button: NumberPadButton) -> some View {
        switch button {
        case .digit(let d):
            Button(action: { onDigit(d) }) {
                Text(d)
                    .font(.system(size: 28, weight: .medium))
                    .frame(width: 72, height: 72)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        case .delete:
            Button(action: onDelete) {
                Image(systemName: "delete.left")
                    .font(.system(size: 22))
                    .frame(width: 72, height: 72)
            }
            .buttonStyle(.plain)
        case .empty:
            Color.clear.frame(width: 72, height: 72)
        }
    }

    private enum NumberPadButton {
        case digit(String), delete, empty
    }
}

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var animatableData: CGFloat

    init(shakes: Int) {
        self.shakes = shakes
        self.animatableData = CGFloat(shakes)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(animatableData * .pi * 2) * 10
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - PIN Dots

struct PINDotsView: View {
    let enteredCount: Int
    let totalCount: Int
    var shakeCount: Int = 0

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<totalCount, id: \.self) { index in
                Circle()
                    .fill(index < enteredCount ? Color.accentColor : Color(.systemGray4))
                    .frame(width: 14, height: 14)
            }
        }
        .modifier(ShakeEffect(shakes: shakeCount))
        .animation(.default, value: shakeCount)
    }
}
