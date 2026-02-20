//
//  SettingsView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Settings Destination

enum SettingsDestination: Hashable {
    case buyback
    case clients
    case queue
    case orders
    case enquiries
    case tabBar
    case notifications
    case security
}

extension SettingsDestination {
    /// Map a FeatureTab to its SettingsDestination for overflow navigation
    static func from(_ tab: FeatureTab) -> SettingsDestination? {
        switch tab {
        case .dashboard: nil // Dashboard is always in tab bar
        case .queue: .queue
        case .orders: .orders
        case .buyback: .buyback
        case .enquiries: .enquiries
        }
    }
}

// MARK: - Settings View

/// Staff settings screen with profile, notifications, and logout
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject private var tabConfig = TabBarConfig.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedDestination: SettingsDestination?

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if isRegularWidth {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .alert("Logout", isPresented: $viewModel.showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                Task {
                    await viewModel.logout()
                    appState.onStaffLogout()
                }
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        NavigationStack {
            settingsList
                .navigationDestination(for: SettingsDestination.self) { dest in
                    destinationView(dest)
                }
        }
    }

    // MARK: - iPad Layout

    @ViewBuilder
    private var iPadLayout: some View {
        if selectedDestination == .buyback {
            BuybackListView(onBack: {
                withAnimation { selectedDestination = nil }
            })
        } else if selectedDestination == .clients {
            ClientListView(onBack: {
                withAnimation { selectedDestination = nil }
            })
        } else if isFullScreenDestination(selectedDestination) {
            // Full-screen feature views (queue, orders, enquiries) — use NavigationStack with back button
            NavigationStack {
                destinationView(selectedDestination!)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                withAnimation { selectedDestination = nil }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("More")
                                }
                            }
                        }
                    }
            }
        } else {
            AnimatedSplitView(showDetail: selectedDestination != nil) {
                NavigationStack {
                    settingsList
                }
            } detail: {
                if let dest = selectedDestination {
                    NavigationStack {
                        destinationView(dest)
                    }
                    .id(dest)
                }
            }
        }
    }

    private func isFullScreenDestination(_ dest: SettingsDestination?) -> Bool {
        guard let dest else { return false }
        return dest == .queue || dest == .orders || dest == .enquiries
    }

    // MARK: - Shared Settings List

    private var settingsList: some View {
        List {
            profileSection
            featuresSection
            tabBarSection
            notificationsSection
            securitySection
            appearanceSection
            aboutSection
            accountActionsSection
        }
        .hidesBookingFABOnScroll()
        .navigationTitle("More")
    }

    // MARK: - Destination View

    @ViewBuilder
    private func destinationView(_ dest: SettingsDestination) -> some View {
        switch dest {
        case .buyback:
            BuybackListView(isEmbedded: true)
        case .clients:
            ClientListView(isEmbedded: true)
        case .queue:
            MyQueueView()
                .navigationTitle("My Queue")
        case .orders:
            OrderListView()
                .navigationTitle("Orders")
        case .enquiries:
            EnquiryListView()
                .navigationTitle("Enquiries")
        case .tabBar:
            TabBarSettingsView()
        case .notifications:
            NotificationSettingsView()
        case .security:
            PasscodeSettingsView()
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            if let user = authManager.currentUser {
                HStack(spacing: isRegularWidth ? 16 : 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(
                                width: isRegularWidth ? 68 : 56,
                                height: isRegularWidth ? 68 : 56
                            )

                        Text(user.initials)
                            .font(isRegularWidth ? .title2 : .title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.headline)

                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: roleIcon(for: user.role))
                                .font(.caption2)
                            Text(user.role.displayName)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    if isRegularWidth, let company = authManager.currentCompany {
                        Spacer()

                        Label(company.name, systemImage: "building.2")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, isRegularWidth ? 8 : 4)
            }

            if !isRegularWidth, let company = authManager.currentCompany {
                HStack {
                    Label("Company", systemImage: "building.2")
                    Spacer()
                    Text(company.name)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        Section("Features") {
            // Overflow feature tabs (not in main tab bar)
            ForEach(tabConfig.overflowTabs) { tab in
                if let dest = SettingsDestination.from(tab) {
                    settingsLink(dest, label: tab.label, icon: tab.icon)
                }
            }
            // Clients always here (not a tab bar candidate)
            settingsLink(.clients, label: "Clients", icon: "person.2.fill")
        }
    }

    // MARK: - Tab Bar Section

    private var tabBarSection: some View {
        Section {
            settingsLink(.tabBar, label: "Customise Tab Bar", icon: "square.grid.2x2")
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section("Notifications") {
            settingsLink(.notifications, label: "Push Notifications", icon: "bell.badge")
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        Section("Security") {
            settingsLink(.security, label: "Passcode & \(PasscodeService.shared.biometricType.displayName)", icon: "lock.shield")
        }
    }

    // MARK: - Settings Link Helper

    @ViewBuilder
    private func settingsLink(_ dest: SettingsDestination, label: String, icon: String) -> some View {
        if isRegularWidth {
            Button {
                withAnimation { selectedDestination = dest }
            } label: {
                HStack {
                    Label(label, systemImage: icon)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)
            .listRowBackground(selectedDestination == dest ? Color.accentColor.opacity(0.1) : nil)
        } else {
            NavigationLink(value: dest) {
                Label(label, systemImage: icon)
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker(selection: Binding(
                get: { appearanceManager.currentMode },
                set: { appearanceManager.currentMode = $0 }
            )) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            } label: {
                Label("Theme", systemImage: "paintbrush.fill")
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Build", systemImage: "hammer")
                Spacer()
                Text(viewModel.buildNumber)
                    .foregroundStyle(.secondary)
            }

            if let company = authManager.currentCompany {
                HStack {
                    Label("Currency", systemImage: "dollarsign.circle")
                    Spacer()
                    Text(company.currencyCode ?? "GBP")
                        .foregroundStyle(.secondary)
                }
            }

            Link(destination: URL(string: "https://repairminder.com/privacy-policy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://repairminder.com/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }
        }
    }

    // MARK: - Account Actions Section

    private var accountActionsSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showLogoutConfirmation = true
            } label: {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    // MARK: - Helpers

    private func roleIcon(for role: UserRole) -> String {
        switch role {
        case .masterAdmin, .admin:
            return "shield.fill"
        case .seniorEngineer:
            return "wrench.and.screwdriver.fill"
        case .engineer:
            return "wrench.fill"
        case .office:
            return "desktopcomputer"
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
