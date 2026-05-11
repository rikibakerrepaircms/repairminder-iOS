//
//  ClientStepView.swift
//  Repair Minder
//

import SwiftUI

struct ClientStepView: View {
    @Bindable var viewModel: BookingViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Customer Details")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Search for an existing customer or enter new customer details.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Intake Method picker — only shown for repair / buyback. Accessories
            // and device-sale always map to fixed backend intake methods, so the
            // choice doesn't apply there. Picking mail_in / courier collapses the
            // wizard down to Customer → Summary → Confirmation.
            if viewModel.formData.serviceType == .repair || viewModel.formData.serviceType == .buyback {
                intakeMethodPicker
            }

            // Client Search
            ClientSearchView(
                query: $viewModel.clientSearchQuery,
                results: viewModel.clientSearchResults,
                isSearching: viewModel.isSearchingClients,
                selectedClient: viewModel.formData.existingClient,
                onSearch: { query in
                    Task {
                        await viewModel.searchClients(query: query)
                    }
                },
                onSelect: { client in
                    viewModel.selectClient(client)
                },
                onClear: {
                    viewModel.clearSelectedClient()
                }
            )

            // Selected Client Info
            if let client = viewModel.formData.existingClient {
                selectedClientCard(client)
            }

            Divider()

            // Name Fields
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    FormTextField(
                        label: "First Name",
                        text: $viewModel.formData.firstName,
                        placeholder: "John",
                        isRequired: true
                    )

                    FormTextField(
                        label: "Last Name",
                        text: $viewModel.formData.lastName,
                        placeholder: "Smith"
                    )
                }

                // Email & Phone - side by side on iPad
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 16) {
                            if !viewModel.formData.noEmail {
                                emailField
                            }
                            noEmailToggle
                        }
                        phoneField
                    }
                } else {
                    if !viewModel.formData.noEmail {
                        emailField
                    }
                    noEmailToggle
                    phoneField
                }
            }

            // Address Section (required for buyback)
            if viewModel.formData.requiresAddress || !viewModel.formData.addressLine1.isEmpty {
                addressSection
            }

            // Location Selector (if multiple locations)
            if viewModel.locations.count > 1 {
                locationSelector
            }
        }
    }

    // MARK: - Extracted Fields

    @ViewBuilder
    private var intakeMethodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intake Method")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            // Three radio-style cards — mirrors the web's three-card picker
            // and matches the ticket→order conversion modal's options.
            VStack(spacing: 8) {
                ForEach(IntakeMethod.allCases) { method in
                    intakeOptionRow(method)
                }
            }
        }
    }

    @ViewBuilder
    private func intakeOptionRow(_ method: IntakeMethod) -> some View {
        let isSelected = viewModel.formData.intakeMethod == method
        Button {
            guard viewModel.formData.intakeMethod != method else { return }
            viewModel.formData.intakeMethod = method
            viewModel.onIntakeMethodChanged()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    Text(method.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.platformGray6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.platformGray4, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var emailField: some View {
        FormTextField(
            label: "Email",
            text: $viewModel.formData.email,
            placeholder: "john@example.com",
            keyboardType: .emailAddress,
            autocapitalization: .never,
            isRequired: true,
            isDisabled: viewModel.formData.existingClient != nil
        )
    }

    @ViewBuilder
    private var phoneField: some View {
        FormTextField(
            label: "Phone",
            text: $viewModel.formData.phone,
            placeholder: "07123 456789",
            keyboardType: .phonePad
        )
    }

    @ViewBuilder
    private var noEmailToggle: some View {
        if viewModel.formData.existingClient == nil {
            Toggle(isOn: $viewModel.formData.noEmail) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Customer has no email")
                        .font(.subheadline)
                    Text("A placeholder email will be generated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.accentColor)
        }
    }

    @ViewBuilder
    private func selectedClientCard(_ client: Client) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.blue)
                    Text("Using existing customer")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(client.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label("\(client.effectiveOrderCount) orders", systemImage: "doc.text")
                    Label("\(client.effectiveDeviceCount) devices", systemImage: "iphone")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.clearSelectedClient()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.platformBlue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Address", systemImage: "mappin.circle")
                    .font(.headline)

                if viewModel.formData.requiresAddress {
                    Text("Required for Buyback")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            FormTextField(
                label: "Address Line 1",
                text: $viewModel.formData.addressLine1,
                placeholder: "123 Main Street",
                isRequired: viewModel.formData.requiresAddress
            )

            FormTextField(
                label: "Address Line 2",
                text: $viewModel.formData.addressLine2,
                placeholder: "Flat 1 (optional)"
            )

            HStack(spacing: 12) {
                FormTextField(
                    label: "City",
                    text: $viewModel.formData.city,
                    placeholder: "London",
                    isRequired: viewModel.formData.requiresAddress
                )

                FormTextField(
                    label: "County",
                    text: $viewModel.formData.county,
                    placeholder: "Greater London"
                )
            }

            HStack(spacing: 12) {
                FormTextField(
                    label: "Postcode",
                    text: $viewModel.formData.postcode,
                    placeholder: "SW1A 1AA",
                    autocapitalization: .characters,
                    isRequired: viewModel.formData.requiresAddress
                )

                FormTextField(
                    label: "Country",
                    text: $viewModel.formData.country,
                    placeholder: "United Kingdom",
                    isRequired: viewModel.formData.requiresAddress
                )
            }
        }
    }

    @ViewBuilder
    private var locationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.subheadline)
                .fontWeight(.medium)

            Menu {
                ForEach(viewModel.locations) { location in
                    Button {
                        viewModel.formData.locationId = location.id
                    } label: {
                        HStack {
                            Text(location.name)
                            if viewModel.formData.locationId == location.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedLocationName)
                        .foregroundStyle(viewModel.formData.locationId.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.platformGray6)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var selectedLocationName: String {
        if let location = viewModel.locations.first(where: { $0.id == viewModel.formData.locationId }) {
            return location.name
        }
        return "Select a location..."
    }
}

#Preview {
    ScrollView {
        ClientStepView(viewModel: BookingViewModel())
            .padding()
    }
}
