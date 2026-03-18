//
//  VerticalTimeIndicator.swift
//  Repair Minder
//
//  Created on 18/03/2026.
//

import SwiftUI

// MARK: - Vertical Time Indicator

/// Red horizontal line + dot showing current time in the timeline.
/// Self-contained: updates every 60 seconds via Timer publisher.
struct VerticalTimeIndicator: View {
    let workStartMinutes: Int
    let workEndMinutes: Int
    let pixelsPerMinute: CGFloat

    @State private var currentMinutes = Self.getCurrentMinutes()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var isVisible: Bool {
        currentMinutes >= workStartMinutes && currentMinutes <= workEndMinutes
    }

    private var yPosition: CGFloat {
        CGFloat(currentMinutes - workStartMinutes) * pixelsPerMinute
    }

    var body: some View {
        Group {
            if isVisible {
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: -4)

                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 1.5)
                }
                .offset(y: yPosition)
                .zIndex(100)
            }
        }
        .onReceive(timer) { _ in
            currentMinutes = Self.getCurrentMinutes()
        }
    }

    // MARK: - Helpers

    private static func getCurrentMinutes() -> Int {
        let now = Date()
        let cal = Calendar.current
        return cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
    }
}
