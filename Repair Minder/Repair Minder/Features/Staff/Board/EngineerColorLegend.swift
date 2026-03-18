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
/// Tap an engineer to change their colour from the 12-colour palette.
struct EngineerColorLegend: View {
    let engineers: [EngineerInfo]

    @State private var expanded = false
    @State private var editingEngineerId: String?
    @State private var colorVersion = 0

    var body: some View {
        if !engineers.isEmpty {
            ConditionalGlassContainer(spacing: 6) {
            HStack(spacing: 8) {
                let visible = expanded ? engineers : Array(engineers.prefix(4))
                ForEach(visible) { eng in
                    EngineerChip(
                        engineer: eng,
                        isEditing: editingEngineerId == eng.id,
                        colorVersion: colorVersion,
                        onTap: {
                            editingEngineerId = editingEngineerId == eng.id ? nil : eng.id
                        },
                        onColorPicked: {
                            editingEngineerId = nil
                            colorVersion += 1
                        }
                    )
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

// MARK: - Engineer Chip (with popover)

private struct EngineerChip: View {
    let engineer: EngineerInfo
    let isEditing: Bool
    let colorVersion: Int
    let onTap: () -> Void
    let onColorPicked: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Circle()
                    .fill(EngineerColors.color(for: engineer.id))
                    .frame(width: 10, height: 10)
                Text(engineer.name.components(separatedBy: " ").first ?? engineer.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .legendChipGlass(color: EngineerColors.color(for: engineer.id))
        }
        .buttonStyle(.plain)
        .id("\(engineer.id)-\(colorVersion)")
        .popover(isPresented: .constant(isEditing)) {
            EngineerColorPicker(engineerId: engineer.id, onDismiss: onColorPicked)
        }
    }
}

// MARK: - Engineer Color Picker

/// Grid of 12 palette colours. Tap to assign, checkmark on current.
struct EngineerColorPicker: View {
    let engineerId: String
    let onDismiss: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(spacing: 8) {
            Text("Pick Colour")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<EngineerColors.palette.count, id: \.self) { index in
                    let hex = EngineerColors.palette[index].bg
                    let isCurrent = EngineerColors.hexColors(for: engineerId).bg == hex

                    Button {
                        EngineerColors.setOverride(for: engineerId, paletteIndex: index)
                        onDismiss()
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if isCurrent {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .presentationCompactAdaptation(.popover)
    }
}
