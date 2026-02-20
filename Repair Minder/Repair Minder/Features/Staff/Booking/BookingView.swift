//
//  BookingView.swift
//  Repair Minder
//

import SwiftUI

// NOTE: ServiceType enum is defined in Core/Models/ServiceType.swift (Stage 01)
// NOTE: BookingViewModel is defined in Features/Staff/Booking/BookingViewModel.swift (Stage 02)

struct BookingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedServiceType: ServiceType?
    @State private var viewModel = BookingViewModel()

    /// Filtered service types: only those with backend support AND enabled by company settings.
    /// Uses `isAvailable` (Stage 01) to exclude .accessories/.deviceSale which lack backend flows,
    /// and `buybackEnabled` (from CompanyPublicInfo API) to conditionally hide .buyback.
    var availableServiceTypes: [ServiceType] {
        ServiceType.allCases.filter { type in
            guard type.isAvailable else { return false }
            switch type {
            case .buyback:
                return viewModel.buybackEnabled
            default:
                return true
            }
        }
    }

    /// True while initial data (locations, device types, company info) is still loading.
    /// We wait for this before showing cards so the buybackEnabled flag is resolved
    /// and we don't flash cards that will disappear.
    var isLoading: Bool {
        viewModel.isLoadingLocations
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Loading...")
                } else if availableServiceTypes.count == 1,
                          let onlyType = availableServiceTypes.first {
                    // Only one available type (e.g. buyback disabled) — skip selection,
                    // go straight to wizard
                    Color.clear
                        .onAppear {
                            selectedServiceType = onlyType
                        }
                } else {
                    Spacer()

                    // Service Type Grid
                    VStack(spacing: sizeClass == .regular ? 16 : 0) {
                        if sizeClass == .regular {
                            Text("Select a Service Type")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: sizeClass == .regular ? 24 : 16
                        ) {
                            ForEach(availableServiceTypes) { serviceType in
                                ServiceTypeCard(
                                    serviceType: serviceType,
                                    isRegular: sizeClass == .regular
                                ) {
                                    selectedServiceType = serviceType
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: sizeClass == .regular ? 520 : .infinity)

                    Spacer()
                }
            }
            .navigationTitle("New Booking")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(item: $selectedServiceType) { serviceType in
                BookingWizardView(viewModel: viewModel, serviceType: serviceType, onComplete: {
                    dismiss()
                })
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
}

// MARK: - Service Type Card

struct ServiceTypeCard: View {
    let serviceType: ServiceType
    var isRegular: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: isRegular ? 20 : 16) {
                Circle()
                    .fill(serviceType.color.opacity(0.15))
                    .frame(width: isRegular ? 100 : 80, height: isRegular ? 100 : 80)
                    .overlay {
                        Image(systemName: serviceType.icon)
                            .font(.system(size: isRegular ? 40 : 32))
                            .foregroundStyle(serviceType.color)
                    }

                VStack(spacing: 4) {
                    Text(serviceType.title)
                        .font(isRegular ? .title3 : .headline)
                        .foregroundStyle(.primary)

                    Text(serviceType.subtitle)
                        .font(isRegular ? .subheadline : .caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isRegular ? 32 : 24)
            .padding(.horizontal, isRegular ? 16 : 12)
            .background(Color.platformBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    BookingView()
}

#Preview("Service Card") {
    ServiceTypeCard(serviceType: .repair) {}
        .frame(width: 180)
        .padding()
        .background(Color.platformGroupedBackground)
}
