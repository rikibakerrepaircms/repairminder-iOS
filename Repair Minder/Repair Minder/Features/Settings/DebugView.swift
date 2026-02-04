//
//  DebugView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI
import CoreData

#if DEBUG
struct DebugView: View {
    @ObservedObject private var syncEngine = SyncEngine.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var isSyncing = false
    @State private var isClearing = false

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

            // Sync Status
            Section("Sync") {
                LabeledContent("Status") {
                    Text(statusDescription)
                        .foregroundStyle(statusColor)
                }

                LabeledContent("Pending Changes") {
                    Text("\(syncEngine.pendingChangesCount)")
                        .foregroundStyle(syncEngine.pendingChangesCount > 0 ? .orange : .secondary)
                }

                if let lastSync = syncEngine.lastSyncDate {
                    LabeledContent("Last Sync") {
                        Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                    }
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

            // Debug Actions
            Section("Actions") {
                Button {
                    Task {
                        isSyncing = true
                        await syncEngine.performFullSync()
                        isSyncing = false
                    }
                } label: {
                    HStack {
                        Label("Force Sync", systemImage: "arrow.triangle.2.circlepath")
                        if isSyncing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isSyncing)

                Button(role: .destructive) {
                    Task {
                        isClearing = true
                        await clearCache()
                        isClearing = false
                    }
                } label: {
                    HStack {
                        Label("Clear Local Cache", systemImage: "trash")
                        if isClearing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isClearing)
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

    private var statusDescription: String {
        switch syncEngine.status {
        case .idle:
            return "Idle"
        case .syncing(let progress):
            return "Syncing \(Int(progress * 100))%"
        case .completed:
            return "Completed"
        case .error(let message):
            return "Error: \(message)"
        case .offline:
            return "Offline"
        }
    }

    private var statusColor: Color {
        switch syncEngine.status {
        case .idle, .completed:
            return .secondary
        case .syncing:
            return .blue
        case .error:
            return .red
        case .offline:
            return .orange
        }
    }

    private func clearCache() async {
        let context = CoreDataStack.shared.newBackgroundContext()
        await context.perform {
            let entities = ["CDOrder", "CDDevice", "CDClient", "CDTicket", "CDTicketMessage"]
            for entityName in entities {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                _ = try? context.execute(deleteRequest)
            }
            try? context.save()
        }

        // Clear last sync date
        UserDefaults.standard.removeObject(forKey: "lastSyncDate")
    }
}

#Preview {
    NavigationStack {
        DebugView()
    }
}
#endif
