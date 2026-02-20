//
//  TabBarSettingsView.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import SwiftUI

struct TabBarSettingsView: View {
    @ObservedObject private var config = TabBarConfig.shared

    var body: some View {
        List {
            Section {
                Text("Choose up to 4 tabs for your main menu and drag to reorder. The rest will be accessible from the More tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            // Section 1: Tab Bar Order
            Section("Tab Bar Order") {
                // Dashboard — locked, not draggable
                HStack(spacing: 12) {
                    Image(systemName: FeatureTab.dashboard.icon)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28)

                    Text(FeatureTab.dashboard.label)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .opacity(0.7)

                // Customisable tabs — draggable, removable
                ForEach(config.customisableTabs) { tab in
                    HStack(spacing: 12) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28)

                        Text(tab.label)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet.sorted().reversed() {
                        let tab = config.customisableTabs[index]
                        withAnimation {
                            config.removeTab(tab)
                        }
                    }
                }
                .onMove { source, destination in
                    config.moveTab(from: source, to: destination)
                }
            }
            .environment(\.editMode, .constant(.active))

            // Section 2: Available (overflow tabs)
            if !config.overflowTabs.isEmpty {
                Section("Available") {
                    ForEach(config.overflowTabs) { tab in
                        Button {
                            withAnimation {
                                config.addTab(tab)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: tab.icon)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)

                                Text(tab.label)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(config.selectedTabs.count < TabBarConfig.maxTabs ? .green : Color.secondary.opacity(0.3))
                            }
                        }
                        .disabled(config.selectedTabs.count >= TabBarConfig.maxTabs)
                    }
                }
            }

            // Footer
            Section {
                HStack {
                    Spacer()
                    Text("\(config.selectedTabs.count) of \(TabBarConfig.maxTabs) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .listRowBackground(Color.clear)

                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        withAnimation {
                            config.resetToDefaults()
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Customise Tab Bar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TabBarSettingsView()
    }
}
