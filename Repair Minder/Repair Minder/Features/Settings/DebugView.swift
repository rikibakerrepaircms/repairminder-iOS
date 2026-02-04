//
//  DebugView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

#if DEBUG
struct DebugView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        List {
            // Network Status
            Section("Network") {
                LabeledContent("Connected") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(networkMonitor.isConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(networkMonitor.isConnected ? "Yes" : "No")
                    }
                }

                LabeledContent("Connection Type") {
                    Text(networkMonitor.connectionType.rawValue.capitalized)
                }
            }

            // Auth Info
            Section("Authentication") {
                if let token = KeychainManager.shared.getString(for: .accessToken) {
                    LabeledContent("Token Prefix") {
                        Text(String(token.prefix(20)) + "...")
                            .font(.caption)
                            .monospaced()
                    }
                } else {
                    LabeledContent("Token") {
                        Text("Not found")
                            .foregroundStyle(.secondary)
                    }
                }

                if let expiresAt = KeychainManager.shared.getDate(for: .tokenExpiresAt) {
                    LabeledContent("Expires") {
                        Text(expiresAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(expiresAt < Date() ? .red : .secondary)
                    }
                }
            }

            // Build Info
            Section("Build") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A")
                }

                LabeledContent("Build") {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A")
                }

                LabeledContent("Bundle ID") {
                    Text(Bundle.main.bundleIdentifier ?? "N/A")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DebugView()
    }
}
#endif
