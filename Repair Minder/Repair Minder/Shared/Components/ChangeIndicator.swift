//
//  ChangeIndicator.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ChangeIndicator: View {
    let percentage: Double

    private var isPositive: Bool {
        percentage >= 0
    }

    private var displayPercentage: String {
        String(format: "%.1f%%", abs(percentage))
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)

            Text(displayPercentage)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(isPositive ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (isPositive ? Color.green : Color.red).opacity(0.15)
        )
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        ChangeIndicator(percentage: 12.5)
        ChangeIndicator(percentage: -5.2)
        ChangeIndicator(percentage: 0)
        ChangeIndicator(percentage: 100.0)
        ChangeIndicator(percentage: -0.5)
    }
    .padding()
}
