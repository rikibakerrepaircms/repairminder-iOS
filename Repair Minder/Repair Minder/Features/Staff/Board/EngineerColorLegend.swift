//
//  EngineerColorLegend.swift
//  Repair Minder
//
//  Created on 18/03/2026.
//

import SwiftUI

// MARK: - Engineer Color Legend

/// Compact horizontal legend showing engineer → colour dot mapping.
/// Shows first 4 engineers; expand/collapse button for additional.
struct EngineerColorLegend: View {
    let engineers: [EngineerInfo]

    @State private var expanded = false

    var body: some View {
        if !engineers.isEmpty {
            ConditionalGlassContainer(spacing: 6) {
            HStack(spacing: 8) {
                let visible = expanded ? engineers : Array(engineers.prefix(4))
                ForEach(visible) { eng in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(EngineerColors.color(for: eng.id))
                            .frame(width: 10, height: 10)
                        Text(eng.name.components(separatedBy: " ").first ?? eng.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .legendChipGlass(color: EngineerColors.color(for: eng.id))
                }

                if engineers.count > 4 {
                    Button(expanded ? "Less" : "+\(engineers.count - 4)") {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }
            }
            } // ConditionalGlassContainer
        }
    }
}
