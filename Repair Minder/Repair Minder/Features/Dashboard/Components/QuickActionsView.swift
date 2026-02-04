//
//  QuickActionsView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct QuickActionsView: View {
    @Environment(AppRouter.self) private var router
    @State private var showNewOrderSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "New Order",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    showNewOrderSheet = true
                }

                QuickActionButton(
                    title: "Scan",
                    icon: "qrcode.viewfinder",
                    color: .green
                ) {
                    router.navigate(to: .scanner)
                }

                QuickActionButton(
                    title: "Devices",
                    icon: "iphone",
                    color: .orange
                ) {
                    router.navigate(to: .devices)
                }
            }
        }
        .sheet(isPresented: $showNewOrderSheet) {
            NewOrderPlaceholderSheet()
                .presentationDetents([.medium])
        }
    }
}

// MARK: - New Order Placeholder Sheet

struct NewOrderPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "hammer.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("Create Order")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Order creation from the app is coming soon. For now, you can create orders via the web app.")
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
            .navigationTitle("New Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func openWebApp() {
        #if canImport(UIKit)
        if let url = URL(string: "https://app.repairminder.com/orders/new") {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickActionsView()
        .environment(AppRouter())
        .padding()
}
