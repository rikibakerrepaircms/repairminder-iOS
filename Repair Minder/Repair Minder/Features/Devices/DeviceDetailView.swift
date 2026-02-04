//
//  DeviceDetailView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DeviceDetailView: View {
    let deviceId: String
    @StateObject private var viewModel: DeviceDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) var router

    init(deviceId: String) {
        self.deviceId = deviceId
        _viewModel = StateObject(wrappedValue: DeviceDetailViewModel(deviceId: deviceId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(message: "Loading device...")
            } else if let device = viewModel.device {
                ScrollView {
                    VStack(spacing: 20) {
                        DeviceHeaderCard(device: device)

                        if device.status.isActive {
                            DeviceStatusActions(
                                currentStatus: device.status,
                                isUpdating: viewModel.isUpdating,
                                onStatusChange: { status in
                                    Task { await viewModel.updateStatus(status) }
                                }
                            )
                        }

                        DeviceInfoCard(device: device)

                        if let notes = device.notes, !notes.isEmpty {
                            NotesCard(notes: notes)
                        }

                        if let orderId = device.orderId {
                            OrderLinkCard(
                                orderId: orderId,
                                onNavigate: {
                                    router.navigate(to: .orderDetail(id: orderId))
                                }
                            )
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    Task { await viewModel.loadDevice() }
                }
            }
        }
        .navigationTitle(viewModel.device?.displayName ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDevice()
        }
    }
}

// MARK: - Notes Card

private struct NotesCard: View {
    let notes: [Device.DeviceNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(notes.indices, id: \.self) { index in
                    if let body = notes[index].body, !body.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(body)
                                .font(.subheadline)

                            if let createdBy = notes[index].createdBy {
                                Text(createdBy)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        DeviceDetailView(deviceId: "test-id")
    }
    .environment(AppRouter())
}
