//
//  SyncStatusBanner.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct SyncStatusBanner: View {
    let status: SyncEngine.SyncStatus
    let pendingCount: Int

    var body: some View {
        Group {
            switch status {
            case .syncing(let progress):
                syncingBanner(progress: progress)
            case .offline:
                offlineBanner
            case .error(let message):
                errorBanner(message: message)
            case .idle, .completed:
                if pendingCount > 0 {
                    pendingBanner
                }
            }
        }
        .padding(.horizontal)
    }

    private func syncingBanner(progress: Double) -> some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)

            Text("Syncing...")
                .font(.subheadline)

            Spacer()

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var offlineBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)

            Text("You're offline")
                .font(.subheadline)

            Spacer()

            Text("Changes will sync when online")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)

            Text("Sync error")
                .font(.subheadline)

            Spacer()

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var pendingBanner: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)

            Text("\(pendingCount) pending change\(pendingCount == 1 ? "" : "s")")
                .font(.subheadline)

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 16) {
        SyncStatusBanner(status: .syncing(progress: 0.5), pendingCount: 0)
        SyncStatusBanner(status: .offline, pendingCount: 3)
        SyncStatusBanner(status: .error("Network timeout"), pendingCount: 0)
        SyncStatusBanner(status: .idle, pendingCount: 2)
        SyncStatusBanner(status: .completed, pendingCount: 0)
    }
    .padding()
}
