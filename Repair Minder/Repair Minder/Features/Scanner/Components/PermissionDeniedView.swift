//
//  PermissionDeniedView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI
import UIKit

struct PermissionDeniedView: View {
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Please enable camera access in Settings to scan QR codes and barcodes for quick device lookup.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    openSettings()
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    onManualEntry()
                } label: {
                    Text("Enter Code Manually")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding()
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }
}

#Preview {
    PermissionDeniedView(onManualEntry: {})
}
