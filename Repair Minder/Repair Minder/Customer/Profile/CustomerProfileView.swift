//
//  CustomerProfileView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct CustomerProfileView: View {
    @Environment(CustomerAuthManager.self) private var authManager
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Account section
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: 60, height: 60)

                            Text(avatarInitial)
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.customerEmail ?? "Customer")
                                .font(.headline)

                            Text("Customer Account")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Preferences section
                Section("Preferences") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                }

                // Support section
                Section("Support") {
                    Link(destination: URL(string: "https://help.repairminder.com")!) {
                        Label("Help Center", systemImage: "questionmark.circle.fill")
                    }

                    Link(destination: URL(string: "mailto:support@repairminder.com")!) {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                }

                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        LegalView()
                    } label: {
                        Text("Terms & Privacy")
                    }
                }

                // Logout section
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog(
                "Log Out",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive) {
                    Task {
                        await authManager.logout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }

    private var avatarInitial: String {
        if let email = authManager.customerEmail, let first = email.first {
            return String(first).uppercased()
        }
        return "C"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @State private var orderUpdates = true
    @State private var quoteAlerts = true
    @State private var enquiryReplies = true
    @State private var marketingMessages = false

    var body: some View {
        List {
            Section {
                Toggle("Order Updates", isOn: $orderUpdates)
                Toggle("Quote Alerts", isOn: $quoteAlerts)
                Toggle("Enquiry Replies", isOn: $enquiryReplies)
            } header: {
                Text("Push Notifications")
            } footer: {
                Text("Get notified about important updates to your repairs")
            }

            Section {
                Toggle("Marketing Messages", isOn: $marketingMessages)
            } footer: {
                Text("Receive offers and promotions from repair shops")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Legal View

struct LegalView: View {
    var body: some View {
        List {
            NavigationLink {
                WebContentView(title: "Terms of Service", url: "https://repairminder.com/terms")
            } label: {
                Text("Terms of Service")
            }

            NavigationLink {
                WebContentView(title: "Privacy Policy", url: "https://repairminder.com/privacy")
            } label: {
                Text("Privacy Policy")
            }
        }
        .navigationTitle("Legal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Web Content View

struct WebContentView: View {
    let title: String
    let url: String

    var body: some View {
        VStack {
            if let url = URL(string: url) {
                Link("Open in Browser", destination: url)
                    .font(.headline)
            }

            Text("Content would be displayed here using WKWebView in a full implementation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CustomerProfileView()
        .environment(CustomerAuthManager())
}
