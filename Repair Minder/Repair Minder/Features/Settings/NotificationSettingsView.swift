//
//  NotificationSettingsView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI
import os.log

// MARK: - View Model

@MainActor
@Observable
final class NotificationSettingsViewModel {
    private(set) var preferences: PushNotificationPreferences = .defaultPreferences
    private(set) var isLoading = false
    private(set) var isSaving = false
    var errorMessage: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "NotificationSettings")

    func loadPreferences() async {
        isLoading = true
        errorMessage = nil

        do {
            struct PreferencesResponse: Decodable {
                let preferences: PushNotificationPreferences
            }
            let response: PreferencesResponse = try await APIClient.shared.request(
                .getPushPreferences(),
                responseType: PreferencesResponse.self
            )
            preferences = response.preferences
        } catch APIError.offline {
            // Use local defaults when offline
            logger.info("Offline - using local preferences")
        } catch {
            logger.error("Failed to load preferences: \(error)")
            errorMessage = "Failed to load notification settings"
        }

        isLoading = false
    }

    func savePreferences() async {
        isSaving = true
        errorMessage = nil

        do {
            try await APIClient.shared.requestVoid(.updatePushPreferences(preferences: preferences))
            logger.info("Preferences saved successfully")
        } catch APIError.offline {
            errorMessage = "You're offline. Changes will sync when you reconnect."
        } catch {
            logger.error("Failed to save preferences: \(error)")
            errorMessage = "Failed to save settings"
        }

        isSaving = false
    }

    func updatePreference(keyPath: WritableKeyPath<PushNotificationPreferences, Bool>, value: Bool) {
        preferences[keyPath: keyPath] = value

        // Save immediately when preference changes
        Task {
            await savePreferences()
        }
    }
}

// MARK: - Staff Notification Settings View

struct StaffNotificationSettingsView: View {
    @State private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        List {
            // Master Toggle
            Section {
                Toggle(isOn: Binding(
                    get: { viewModel.preferences.notificationsEnabled },
                    set: { viewModel.updatePreference(keyPath: \.notificationsEnabled, value: $0) }
                )) {
                    Label("Push Notifications", systemImage: "bell.fill")
                }
                .tint(.accentColor)
            } header: {
                Text("Master Control")
            } footer: {
                Text("When disabled, you won't receive any push notifications from the app.")
            }

            // Order Notifications
            Section {
                notificationToggle(
                    "Order Status Updates",
                    systemImage: "doc.text.fill",
                    keyPath: \.orderStatusChanged
                )

                notificationToggle(
                    "New Orders",
                    systemImage: "plus.circle.fill",
                    keyPath: \.orderCreated
                )

                notificationToggle(
                    "Order Collections",
                    systemImage: "checkmark.circle.fill",
                    keyPath: \.orderCollected
                )
            } header: {
                Text("Orders")
            }

            // Device Notifications
            Section {
                notificationToggle(
                    "Device Status Updates",
                    systemImage: "iphone",
                    keyPath: \.deviceStatusChanged
                )
            } header: {
                Text("Devices")
            }

            // Quote Notifications
            Section {
                notificationToggle(
                    "Quote Approved",
                    systemImage: "checkmark.seal.fill",
                    keyPath: \.quoteApproved
                )

                notificationToggle(
                    "Quote Declined",
                    systemImage: "xmark.seal.fill",
                    keyPath: \.quoteRejected
                )
            } header: {
                Text("Quotes")
            }

            // Payment Notifications
            Section {
                notificationToggle(
                    "Payment Received",
                    systemImage: "creditcard.fill",
                    keyPath: \.paymentReceived
                )
            } header: {
                Text("Payments")
            }

            // Enquiry Notifications
            Section {
                notificationToggle(
                    "New Enquiries",
                    systemImage: "envelope.fill",
                    keyPath: \.newEnquiry
                )

                notificationToggle(
                    "Customer Replies",
                    systemImage: "arrowshape.turn.up.left.fill",
                    keyPath: \.enquiryReply
                )
            } header: {
                Text("Enquiries")
            } footer: {
                Text("Get notified when customers submit new enquiries or reply to existing conversations.")
            }

            // System Settings Link
            Section {
                Button {
                    openSystemSettings()
                } label: {
                    HStack {
                        Label("System Notification Settings", systemImage: "gear")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Manage sound, badge, and banner settings in System Settings.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.loadPreferences()
        }
        .disabled(!viewModel.preferences.notificationsEnabled && !viewModel.isLoading)
    }

    @ViewBuilder
    private func notificationToggle(
        _ title: String,
        systemImage: String,
        keyPath: WritableKeyPath<PushNotificationPreferences, Bool>
    ) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.preferences[keyPath: keyPath] },
            set: { viewModel.updatePreference(keyPath: keyPath, value: $0) }
        )) {
            Label(title, systemImage: systemImage)
        }
        .tint(.accentColor)
        .disabled(!viewModel.preferences.notificationsEnabled || viewModel.isSaving)
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        StaffNotificationSettingsView()
    }
}
