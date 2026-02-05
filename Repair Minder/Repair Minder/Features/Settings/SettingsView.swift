//
//  SettingsView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Settings View

/// Staff settings screen with profile, notifications, and logout
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        NavigationStack {
            List {
                // User profile section
                profileSection

                // Navigation section
                navigationSection

                // Notifications section
                notificationsSection

                // Security section
                securitySection

                // Appearance section
                appearanceSection

                // About section
                aboutSection

                // Account actions section
                accountActionsSection
            }
            .navigationTitle("More")
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
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            if let user = authManager.currentUser {
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 56, height: 56)

                        Text(user.initials)
                            .font(.title3)
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
                }
                .padding(.vertical, 4)
            }

            if let company = authManager.currentCompany {
                HStack {
                    Label("Company", systemImage: "building.2")
                    Spacer()
                    Text(company.name)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        Section {
            NavigationLink {
                ClientListView()
            } label: {
                Label("Clients", systemImage: "person.2.fill")
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section("Notifications") {
            NavigationLink {
                NotificationSettingsView()
            } label: {
                Label("Push Notifications", systemImage: "bell.badge")
            }
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        Section("Security") {
            NavigationLink {
                PasscodeSettingsView()
            } label: {
                Label {
                    Text("Passcode & \(PasscodeService.shared.biometricType.displayName)")
                } icon: {
                    Image(systemName: "lock.shield")
                }
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
