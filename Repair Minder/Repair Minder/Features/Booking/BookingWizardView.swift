//
//  BookingWizardView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct BookingWizardView: View {
    let serviceType: ServiceType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: serviceType.icon)
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text(serviceType.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Booking wizard is coming soon. For now, create orders via the web app.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                openWebApp()
                dismiss()
            } label: {
                Label("Open Web App", systemImage: "safari")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .navigationTitle("New \(serviceType.title)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openWebApp() {
        #if canImport(UIKit)
        if let url = URL(string: "https://app.repairminder.com/orders/new") {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        BookingWizardView(serviceType: .repair)
    }
}
