//
//  DeviceSearchPicker.swift
//  Repair Minder
//

import SwiftUI

struct DeviceSearchPicker: View {
    @Bindable var viewModel: BookingViewModel
    @Binding var selectedBrandId: String?
    @Binding var selectedModelId: String?
    @Binding var customBrand: String?
    @Binding var customModel: String?
    @Binding var displayName: String

    @State private var searchQuery: String = ""
    @State private var showResults = false
    @State private var deviceSearchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Search Input
            VStack(alignment: .leading, spacing: 6) {
                Text("Device")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search brand or model...", text: $searchQuery)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)
                        .onChange(of: searchQuery) { _, newValue in
                            showResults = !newValue.isEmpty
                            deviceSearchTask?.cancel()
                            deviceSearchTask = Task {
                                try? await Task.sleep(for: .milliseconds(300))
                                guard !Task.isCancelled else { return }
                                await viewModel.searchDevices(query: newValue)
                            }
                        }

                    if viewModel.isSearchingDevices {
                        ProgressView()
                    } else if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            showResults = false
                            viewModel.deviceSearchResults = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.platformGray6)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Search Results
            if showResults, let results = viewModel.deviceSearchResults {
                VStack(alignment: .leading, spacing: 0) {
                    // Models (more specific — show first)
                    if !results.models.isEmpty {
                        Text("Models")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        ForEach(results.models.prefix(8)) { model in
                            Button {
                                selectModel(model)
                            } label: {
                                HStack {
                                    Image(systemName: "iphone")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    Text(model.fullDisplayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Brands
                    if !results.brands.isEmpty {
                        if !results.models.isEmpty { Divider() }
                        Text("Brands")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        ForEach(results.brands.prefix(5)) { brand in
                            Button {
                                selectBrand(brand)
                            } label: {
                                HStack {
                                    Image(systemName: "building.2")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    Text(brand.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // No results
                    if results.brands.isEmpty && results.models.isEmpty {
                        Text("No matches found — enter custom details below")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(12)
                    }
                }
                .background(Color.platformBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }

            // Selected indicator (when a model/brand was picked)
            if selectedModelId != nil || selectedBrandId != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(displayName)
                        .font(.subheadline)
                    Spacer()
                    Button("Clear") {
                        clearSelection()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Custom brand/model (when no search result used, or manual entry)
            if selectedBrandId == nil && selectedModelId == nil {
                HStack(spacing: 12) {
                    FormTextField(
                        label: "Custom Brand",
                        text: Binding(
                            get: { customBrand ?? "" },
                            set: {
                                customBrand = $0
                                updateDisplayName()
                            }
                        ),
                        placeholder: "e.g. Apple"
                    )

                    FormTextField(
                        label: "Custom Model",
                        text: Binding(
                            get: { customModel ?? "" },
                            set: {
                                customModel = $0
                                updateDisplayName()
                            }
                        ),
                        placeholder: "e.g. iPhone 14 Pro"
                    )
                }
            }

            // Validation: backend requires either a selected brand or custom brand
            if selectedBrandId == nil && (customBrand ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Select a device from search or enter a custom brand name.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Display Name (always editable)
            FormTextField(
                label: "Display Name",
                text: $displayName,
                placeholder: "e.g. Apple iPhone 14 Pro",
                isRequired: true
            )
        }
    }

    private func selectModel(_ model: DeviceSearchModel) {
        selectedBrandId = model.brandId
        selectedModelId = model.id
        customBrand = nil
        customModel = nil
        displayName = model.fullDisplayName
        searchQuery = ""
        showResults = false
        isSearchFocused = false
    }

    private func selectBrand(_ brand: DeviceSearchBrand) {
        selectedBrandId = brand.id
        selectedModelId = nil
        customBrand = nil
        customModel = nil
        displayName = brand.name
        searchQuery = ""
        showResults = false
        isSearchFocused = false
    }

    private func clearSelection() {
        selectedBrandId = nil
        selectedModelId = nil
        customBrand = nil
        customModel = nil
        displayName = ""
    }

    private func updateDisplayName() {
        let brand = customBrand ?? ""
        let model = customModel ?? ""
        let parts = [brand, model].filter { !$0.isEmpty }
        if !parts.isEmpty {
            displayName = parts.joined(separator: " ")
        }
    }
}

#Preview {
    DeviceSearchPicker(
        viewModel: BookingViewModel(),
        selectedBrandId: .constant(nil),
        selectedModelId: .constant(nil),
        customBrand: .constant(nil),
        customModel: .constant(nil),
        displayName: .constant("")
    )
    .padding()
}
