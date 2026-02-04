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

                        if let issue = device.issue, !issue.isEmpty {
                            IssueCard(issue: issue)
                        }

                        DiagnosisForm(
                            diagnosis: $viewModel.diagnosis,
                            resolution: $viewModel.resolution,
                            isSaving: viewModel.isSavingDiagnosis,
                            onSave: {
                                Task { await viewModel.saveDiagnosis() }
                            }
                        )

                        PricingCard(
                            price: device.price,
                            editedPrice: $viewModel.editedPrice,
                            isEditing: $viewModel.isEditingPrice,
                            isSaving: viewModel.isSavingPrice,
                            onSave: {
                                Task { await viewModel.savePrice() }
                            }
                        )

                        OrderLinkCard(
                            orderId: device.orderId,
                            onNavigate: {
                                router.navigate(to: .orderDetail(id: device.orderId))
                            }
                        )
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

#Preview {
    NavigationStack {
        DeviceDetailView(deviceId: "test-id")
    }
    .environment(AppRouter())
}
