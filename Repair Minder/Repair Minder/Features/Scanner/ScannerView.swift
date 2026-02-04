//
//  ScannerView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ScannerView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel = ScannerViewModel()
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.permissionDenied {
                    PermissionDeniedView(onManualEntry: {
                        showManualEntry = true
                    })
                } else if viewModel.isLoading {
                    LoadingStateView()
                } else if let result = viewModel.scanResult {
                    ScanResultView(
                        result: result,
                        onNavigate: handleNavigation,
                        onRescan: {
                            viewModel.resetScan()
                        }
                    )
                } else {
                    // Camera Preview
                    CameraPreviewView(session: viewModel.captureSession)
                        .ignoresSafeArea()

                    // Overlay with scan frame
                    ScannerOverlay(isScanning: viewModel.isScanning)

                    // Manual Entry Button
                    VStack {
                        Spacer()

                        Button {
                            showManualEntry = true
                        } label: {
                            Label("Enter Code Manually", systemImage: "keyboard")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .padding(.bottom, 50)
                    }
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if viewModel.isScanning {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showManualEntry = true
                        } label: {
                            Image(systemName: "keyboard")
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .onAppear {
                viewModel.checkPermission()
                if !viewModel.permissionDenied {
                    viewModel.startScanning()
                }
            }
            .onDisappear {
                viewModel.stopScanning()
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView { code in
                    Task {
                        await viewModel.lookupCode(code)
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
        }
    }

    private func handleNavigation(_ result: ScannerViewModel.ScanResult) {
        switch result {
        case .device(let device):
            router.navigate(to: .deviceDetail(id: device.id))
        case .order(let order):
            router.navigate(to: .orderDetail(id: order.id))
        case .unknown:
            break
        }
    }
}

// MARK: - Loading State View
private struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Looking up code...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ScannerView()
        .environment(AppRouter())
}
