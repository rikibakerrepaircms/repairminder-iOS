//
//  TabBarConfig.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import Foundation
import SwiftUI

/// All feature tabs that can appear in the main tab bar.
/// "More" is not included — it's always present as the 5th tab.
enum FeatureTab: String, CaseIterable, Identifiable, Codable {
    case dashboard
    case queue
    case orders
    case buyback
    case enquiries
    case clients

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: "Dashboard"
        case .queue: "My Queue"
        case .orders: "Orders"
        case .buyback: "Buyback"
        case .enquiries: "Enquiries"
        case .clients: "Clients"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "chart.bar.fill"
        case .queue: "tray.full.fill"
        case .orders: "doc.text.fill"
        case .buyback: "arrow.triangle.2.circlepath"
        case .enquiries: "envelope.fill"
        case .clients: "person.2.fill"
        }
    }

    /// Fixed fallback order used for sorting overflow tabs
    var fallbackOrder: Int {
        switch self {
        case .dashboard: 0
        case .queue: 1
        case .orders: 2
        case .buyback: 3
        case .enquiries: 4
        case .clients: 5
        }
    }
}

/// Manages which tabs are shown in the main tab bar and their order.
/// Dashboard is always locked at position 0. The user chooses and orders
/// up to 3 tabs from {queue, orders, buyback, enquiries} for positions 1-3.
/// Persists the ordered array to UserDefaults as JSON.
@MainActor
final class TabBarConfig: ObservableObject {
    static let shared = TabBarConfig()

    static let defaultTabs: [FeatureTab] = [.dashboard, .queue, .orders, .enquiries]
    static let maxTabs = 4 // dashboard + 3 custom

    private let storageKey = "tabBarSelectedTabs"

    /// The tabs currently in the tab bar, in display order.
    /// Index 0 is ALWAYS .dashboard.
    @Published var selectedTabs: [FeatureTab] {
        didSet { save() }
    }

    /// Tabs not in the tab bar, sorted by fixed fallback order.
    var overflowTabs: [FeatureTab] {
        FeatureTab.allCases
            .filter { !selectedTabs.contains($0) }
            .sorted { $0.fallbackOrder < $1.fallbackOrder }
    }

    /// The customisable portion (everything after dashboard) — these are draggable.
    var customisableTabs: [FeatureTab] {
        Array(selectedTabs.dropFirst())
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([FeatureTab].self, from: data),
           !decoded.isEmpty,
           decoded[0] == .dashboard,
           decoded.count <= Self.maxTabs,
           Set(decoded).count == decoded.count // no duplicates
        {
            self.selectedTabs = decoded
        } else {
            self.selectedTabs = Self.defaultTabs
        }
    }

    func isSelected(_ tab: FeatureTab) -> Bool {
        selectedTabs.contains(tab)
    }

    /// Add a tab to the end of the tab bar (after current custom tabs).
    func addTab(_ tab: FeatureTab) {
        guard tab != .dashboard else { return }
        guard !selectedTabs.contains(tab) else { return }
        guard selectedTabs.count < Self.maxTabs else { return }
        selectedTabs.append(tab)
    }

    /// Remove a tab from the tab bar. Refuses to remove .dashboard.
    func removeTab(_ tab: FeatureTab) {
        guard tab != .dashboard else { return }
        selectedTabs.removeAll { $0 == tab }
    }

    /// Reorder within selectedTabs. Dashboard (index 0) stays locked.
    func moveTab(from source: IndexSet, to destination: Int) {
        // Offset by 1 because the caller works with customisableTabs (0-indexed from position 1)
        let adjustedSource = IndexSet(source.map { $0 + 1 })
        let adjustedDestination = destination + 1

        // Clamp: don't allow anything to move to index 0 (dashboard's spot)
        guard adjustedDestination >= 1 else { return }

        selectedTabs.move(fromOffsets: adjustedSource, toOffset: adjustedDestination)

        // Safety: ensure dashboard is still first
        if selectedTabs.first != .dashboard {
            selectedTabs.removeAll { $0 == .dashboard }
            selectedTabs.insert(.dashboard, at: 0)
        }
    }

    func resetToDefaults() {
        selectedTabs = Self.defaultTabs
    }

    private func save() {
        if let data = try? JSONEncoder().encode(selectedTabs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
