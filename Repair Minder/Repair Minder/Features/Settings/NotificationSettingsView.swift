//
//  NotificationSettingsView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Notification Settings View

/// Push notification preferences settings screen
struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationSettingsViewModel()
    @ObservedObject private var pushService = PushNotificationService.shared

    var body: some View {
        List {
            // Debug section - shows token status
            debugSection

            // System permission section
            systemPermissionSection

            // Master toggle section
            if viewModel.hasSystemPermission {
                masterToggleSection

                // Individual preferences (only if master toggle is on)
                if viewModel.preferences.notificationsEnabled {
                    ordersSection
                    quotesPaymentsSection
                    devicesSection
                    enquiriesSection
                }
            }
        }
        .navigationTitle("Push Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }

    // MARK: - Debug Section

    private var authStatusText: String {
        switch pushService.authorizationStatus {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private var debugSection: some View {
        Section("Push Status (Debug)") {
            HStack {
                Text("APNs Token")
                Spacer()
                if let token = pushService.deviceToken {
                    Text(String(token.prefix(16)) + "...")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("Not received")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Text("Authorization")
                Spacer()
                Text(authStatusText)
                    .font(.caption)
                    .foregroundStyle(pushService.isSystemEnabled ? .green : .orange)
            }

            if let error = pushService.errorMessage {
                HStack {
                    Text("Error")
                    Spacer()
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Button("Re-register Token") {
                Task {
                    _ = await pushService.requestAuthorization()
                    if pushService.deviceToken != nil {
                        await pushService.registerToken(appType: "staff")
                    }
                }
            }
            .disabled(pushService.isLoading)
        }
    }

    // MARK: - System Permission Section

    private var systemPermissionSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Permission")
                        .font(.headline)

                    Text(viewModel.systemPermissionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.hasSystemPermission {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Enable") {
                        viewModel.openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
        } footer: {
            if !viewModel.hasSystemPermission {
                Text("Push notifications are disabled at the system level. Tap Enable to open Settings.")
            }
        }
    }

    // MARK: - Master Toggle Section

    private var masterToggleSection: some View {
        Section {
            Toggle(isOn: $viewModel.preferences.notificationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Notifications")
                        .font(.headline)
                    Text("Receive push notifications from Repair Minder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: viewModel.preferences.notificationsEnabled) { _, newValue in
                Task {
                    await viewModel.updateMasterToggle(newValue)
                }
            }
        }
    }

    // MARK: - Orders Section

    private var ordersSection: some View {
        Section("Orders") {
            preferenceToggle(
                title: "Order Created",
                subtitle: "New orders in your queue",
                keyPath: \.orderCreated,
                updateKey: \.orderCreated
            )

            preferenceToggle(
                title: "Status Changed",
                subtitle: "Order status updates",
                keyPath: \.orderStatusChanged,
                updateKey: \.orderStatusChanged
            )

            preferenceToggle(
                title: "Order Collected",
                subtitle: "Customer collected their order",
                keyPath: \.orderCollected,
                updateKey: \.orderCollected
            )
        }
    }

    // MARK: - Quotes & Payments Section

    private var quotesPaymentsSection: some View {
        Section("Quotes & Payments") {
            preferenceToggle(
                title: "Quote Approved",
                subtitle: "Customer approved a quote",
                keyPath: \.quoteApproved,
                updateKey: \.quoteApproved
            )

            preferenceToggle(
                title: "Quote Rejected",
                subtitle: "Customer rejected a quote",
                keyPath: \.quoteRejected,
                updateKey: \.quoteRejected
            )

            preferenceToggle(
                title: "Payment Received",
                subtitle: "Payment received for an order",
                keyPath: \.paymentReceived,
                updateKey: \.paymentReceived
            )
        }
    }

    // MARK: - Devices Section

    private var devicesSection: some View {
        Section("Devices") {
            preferenceToggle(
                title: "Device Status Changed",
                subtitle: "Updates on devices you're working on",
                keyPath: \.deviceStatusChanged,
                updateKey: \.deviceStatusChanged
            )
        }
    }

    // MARK: - Enquiries Section

    private var enquiriesSection: some View {
        Section("Enquiries") {
            preferenceToggle(
                title: "New Enquiry",
                subtitle: "New customer enquiries",
                keyPath: \.newEnquiry,
                updateKey: \.newEnquiry
            )

            preferenceToggle(
                title: "Enquiry Reply",
                subtitle: "Customer replied to an enquiry",
                keyPath: \.enquiryReply,
                updateKey: \.enquiryReply
            )
        }
    }

    // MARK: - Preference Toggle Helper

    @ViewBuilder
    private func preferenceToggle(
        title: String,
        subtitle: String,
        keyPath: WritableKeyPath<PushPreferences, Bool>,
        updateKey: WritableKeyPath<PushPreferencesUpdateRequest, Bool?>
    ) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.preferences[keyPath: keyPath] },
            set: { newValue in
                viewModel.preferences[keyPath: keyPath] = newValue
                Task {
                    await viewModel.updateSinglePreference(key: updateKey, value: newValue)
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(viewModel.isUpdating)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
