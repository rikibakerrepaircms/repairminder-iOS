//
//  SettingsView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: SettingsViewModel?
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    settingsContent(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
            .task {
                if viewModel == nil {
                    viewModel = SettingsViewModel(appState: appState)
                }
            }
        }
    }

    @ViewBuilder
    private func settingsContent(_ vm: SettingsViewModel) -> some View {
        List {
            // User Profile Section
            if let user = vm.currentUser {
                Section {
                    UserProfileHeader(user: user, company: vm.currentCompany)
                }
            }

            // Preferences Section
            Section("Preferences") {
                NavigationLink {
                    StaffNotificationSettingsView()
                } label: {
                    Label("Notifications", systemImage: "bell.fill")
                }

                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label("Appearance", systemImage: "paintbrush.fill")
                }
            }

            // Support Section
            Section("Support") {
                Button {
                    vm.openHelpCenter()
                } label: {
                    HStack {
                        Label("Help Center", systemImage: "questionmark.circle.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    vm.openContactSupport()
                } label: {
                    HStack {
                        Label("Contact Support", systemImage: "envelope.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // About Section
            Section("About") {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About Repair Minder", systemImage: "info.circle.fill")
                }

                #if DEBUG
                NavigationLink {
                    DebugView()
                } label: {
                    Label("Debug Info", systemImage: "ant.fill")
                        .foregroundStyle(.orange)
                }
                #endif
            }

            // Sign Out Section
            Section {
                Button(role: .destructive) {
                    showLogoutConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        Spacer()
                    }
                }
            }
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await vm.logout()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to logout?")
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
