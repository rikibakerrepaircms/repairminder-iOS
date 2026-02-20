//
//  StatCard.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Stat Card

/// Reusable card for displaying a statistic with comparison
struct StatCard: View {
    let title: String
    let value: String
    let change: Double?
    let changePercent: Double?
    let prefix: String?
    let icon: String?
    let iconColor: Color

    init(
        title: String,
        value: String,
        change: Double? = nil,
        changePercent: Double? = nil,
        prefix: String? = nil,
        icon: String? = nil,
        iconColor: Color = .blue
    ) {
        self.title = title
        self.value = value
        self.change = change
        self.changePercent = changePercent
        self.prefix = prefix
        self.icon = icon
        self.iconColor = iconColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with title and icon
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(iconColor)
                }
            }

            // Value
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if let prefix = prefix {
                    Text(prefix)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }

            // Change indicator
            if let changePercent = changePercent {
                ChangeIndicator(
                    change: change,
                    changePercent: changePercent
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Change Indicator

/// Shows the change percentage with up/down arrow
struct ChangeIndicator: View {
    let change: Double?
    let changePercent: Double

    private var direction: ChangeDirection {
        if changePercent > 0 { return .up }
        if changePercent < 0 { return .down }
        return .neutral
    }

    private var color: Color {
        switch direction {
        case .up: return .green
        case .down: return .red
        case .neutral: return .secondary
        }
    }

    private var icon: String {
        switch direction {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .neutral: return "minus"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))

            Text(String(format: "%.1f%%", abs(changePercent)))
                .font(.caption.weight(.medium))

            if let change = change, change != 0 {
                Text("(\(change > 0 ? "+" : "")\(formatChange(change)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(color)
    }

    private func formatChange(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Stat Card Variants

extension StatCard {
    /// Create a stat card for device count
    static func deviceCount(
        _ count: Int,
        change: Double? = nil,
        changePercent: Double? = nil
    ) -> StatCard {
        StatCard(
            title: "Devices Completed",
            value: "\(count)",
            change: change,
            changePercent: changePercent,
            icon: "iphone",
            iconColor: .blue
        )
    }

    /// Create a stat card for revenue
    static func revenue(
        _ total: Double,
        currencySymbol: String = "£",
        change: Double? = nil,
        changePercent: Double? = nil
    ) -> StatCard {
        StatCard(
            title: "Revenue",
            value: formatCurrency(total),
            change: change,
            changePercent: changePercent,
            prefix: currencySymbol,
            icon: "banknote",
            iconColor: .green
        )
    }

    /// Create a stat card for client count
    static func clients(
        _ count: Int,
        title: String = "Clients",
        change: Double? = nil,
        changePercent: Double? = nil
    ) -> StatCard {
        StatCard(
            title: title,
            value: "\(count)",
            change: change,
            changePercent: changePercent,
            icon: "person.2",
            iconColor: .purple
        )
    }

    private static func formatCurrency(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Stat Grid

/// Grid layout for multiple stat cards
struct StatGrid<Content: View>: View {
    let columns: Int
    let content: () -> Content

    init(columns: Int = 2, @ViewBuilder content: @escaping () -> Content) {
        self.columns = columns
        self.content = content
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns),
            spacing: 12
        ) {
            content()
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            StatGrid {
                StatCard.deviceCount(42, change: 5, changePercent: 13.5)
                StatCard.revenue(1250.50, change: 150, changePercent: 13.6)
                StatCard.clients(28, change: 3, changePercent: 12.0)
                StatCard.clients(5, title: "New Clients", change: -2, changePercent: -28.6)
            }

            StatCard(
                title: "Custom Stat",
                value: "100",
                change: nil,
                changePercent: nil,
                icon: "star.fill",
                iconColor: .yellow
            )
        }
        .padding()
    }
    .background(Color.platformGroupedBackground)
}
