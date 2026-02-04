//
//  OfflineBanner.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct OfflineBanner: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.subheadline.weight(.semibold))

                Text("You're offline")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text("Check your connection")
                    .font(.caption)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange.gradient)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You're currently offline. Check your connection.")
        }
    }
}

#Preview("Online") {
    VStack(spacing: 0) {
        OfflineBanner()
        Spacer()
    }
}

#Preview("Offline") {
    VStack(spacing: 0) {
        // Force show the banner for preview
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline.weight(.semibold))

            Text("You're offline")
                .font(.subheadline.weight(.medium))

            Spacer()

            Text("Changes will sync when reconnected")
                .font(.caption)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.gradient)

        Spacer()
    }
}
