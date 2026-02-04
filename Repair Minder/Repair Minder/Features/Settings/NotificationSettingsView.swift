//
//  NotificationSettingsView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct StaffNotificationSettingsView: View {
    @AppStorage("notif_orders") private var ordersEnabled = true
    @AppStorage("notif_devices") private var devicesEnabled = true
    @AppStorage("notif_messages") private var messagesEnabled = true
    @AppStorage("notif_payments") private var paymentsEnabled = true
    @AppStorage("notif_enquiries") private var enquiriesEnabled = true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $ordersEnabled) {
                    Label("Order Updates", systemImage: "doc.text.fill")
                }
                .tint(.accentColor)

                Toggle(isOn: $devicesEnabled) {
                    Label("Device Assignments", systemImage: "iphone")
                }
                .tint(.accentColor)

                Toggle(isOn: $messagesEnabled) {
                    Label("New Messages", systemImage: "message.fill")
                }
                .tint(.accentColor)

                Toggle(isOn: $paymentsEnabled) {
                    Label("Payment Received", systemImage: "creditcard.fill")
                }
                .tint(.accentColor)

                Toggle(isOn: $enquiriesEnabled) {
                    Label("New Enquiries", systemImage: "envelope.fill")
                }
                .tint(.accentColor)
            } header: {
                Text("Notification Types")
            } footer: {
                Text("Choose which notifications you'd like to receive. These settings only affect in-app notification preferences.")
            }

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
                Text("To completely disable notifications or manage sound and badge settings, go to System Settings.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
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
