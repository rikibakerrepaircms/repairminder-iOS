//
//  AccessoriesBookingView.swift
//  Repair Minder
//
//  Simplified single-screen booking flow for accessories orders.
//  Supports guest checkout (skip customer details) for quick counter sales.
//

import SwiftUI
import os.log

struct AccessoriesBookingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    let onComplete: () -> Void

    @State private var guestCheckout = false
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var locationId = ""
    @State private var selectedClient: Client?

    @State private var locations: [Location] = []
    @State private var isLoadingLocations = true
    @State private var isSubmitting = false
    @State private var submitError: String?

    // Client search
    @State private var clientSearchQuery = ""
    @State private var clientSearchResults: [Client] = []
    @State private var isSearchingClients = false

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "AccessoriesBooking")

    private var isValid: Bool {
        if guestCheckout {
            return locations.count < 2 || !locationId.isEmpty
        } else {
            return !firstName.isEmpty && isValidEmail(email) && (locations.count < 2 || !locationId.isEmpty)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    guestCheckoutCard
                    if !guestCheckout {
                        customerDetailsSection
                    }
                    if locations.count >= 2 {
                        locationSection
                    }
                }
                .padding()
            }

            Divider()
            footerBar
        }
        .background(Color.platformGroupedBackground)
        .navigationTitle("Accessories Order")
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
        .task {
            await loadLocations()
        }
    }

    // MARK: - Guest Checkout Card

    private var guestCheckoutCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                guestCheckout.toggle()
                if guestCheckout {
                    email = ""
                    firstName = ""
                    lastName = ""
                    phone = ""
                    selectedClient = nil
                    clientSearchQuery = ""
                    clientSearchResults = []
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                RoundedRectangle(cornerRadius: 6)
                    .fill(guestCheckout ? Color.purple : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(guestCheckout ? Color.purple : Color.secondary.opacity(0.4), lineWidth: 2)
                    )
                    .overlay {
                        if guestCheckout {
                            Image(systemName: "checkmark")
                                .font(.system(size: sizeClass == .regular ? 16 : 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: sizeClass == .regular ? 28 : 24, height: sizeClass == .regular ? 28 : 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Guest Checkout")
                        .font(sizeClass == .regular ? .title3 : .body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text("Skip customer details for quick sales")
                        .font(sizeClass == .regular ? .subheadline : .caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(sizeClass == .regular ? 20 : 16)
            .background(Color.platformBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Customer Details

    private var customerDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customer Details")
                .font(.headline)

            // Client search
            ClientSearchView(
                query: $clientSearchQuery,
                results: clientSearchResults,
                isSearching: isSearchingClients,
                selectedClient: selectedClient,
                onSearch: { query in
                    Task { await searchClients(query: query) }
                },
                onSelect: { client in
                    selectClient(client)
                },
                onClear: {
                    clearClient()
                }
            )

            // Selected client banner
            if selectedClient != nil {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Using existing customer record")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    Spacer()
                    Button("Clear") {
                        clearClient()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
                .padding(12)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Email field
            if selectedClient == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("customer@example.com", text: $email)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Name fields
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("First Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("First name", text: $firstName)
                        .padding()
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Last name", text: $lastName)
                        .padding()
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Phone field
            VStack(alignment: .leading, spacing: 4) {
                Text("Phone")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("07123 456789", text: $phone)
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    #endif
                    .padding()
                    .background(Color.platformGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)

            Picker("Location", selection: $locationId) {
                Text("Select a location...").tag("")
                ForEach(locations) { location in
                    Text(location.name).tag(location.id)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.platformGray6)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Footer

    private var footerBar: some View {
        VStack(spacing: 8) {
            if let error = submitError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal)
            }

            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSubmitting ? "Creating Order..." : "Create Order & Add Items")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValid ? Color.purple : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValid || isSubmitting)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.platformBackground)
    }

    // MARK: - Data Loading

    private func loadLocations() async {
        isLoadingLocations = true
        defer { isLoadingLocations = false }

        do {
            let result: [Location] = try await APIClient.shared.request(.locations)
            locations = result
            if locations.count == 1 {
                locationId = locations[0].id
            }
        } catch {
            logger.error("Failed to load locations: \(error)")
        }
    }

    // MARK: - Client Search

    private func searchClients(query: String) async {
        guard query.count >= 2 else {
            clientSearchResults = []
            return
        }

        isSearchingClients = true
        defer { isSearchingClients = false }

        do {
            let response: ClientSearchResponse = try await APIClient.shared.request(
                .clientSearch(query: query)
            )
            clientSearchResults = response.clients
        } catch {
            logger.error("Failed to search clients: \(error)")
            clientSearchResults = []
        }
    }

    private func selectClient(_ client: Client) {
        selectedClient = client
        email = client.email
        firstName = client.firstName ?? ""
        lastName = client.lastName ?? ""
        phone = client.phone ?? ""
        clientSearchQuery = ""
        clientSearchResults = []
    }

    private func clearClient() {
        selectedClient = nil
        email = ""
        firstName = ""
        lastName = ""
        phone = ""
    }

    // MARK: - Submission

    private func submit() async {
        guard isValid else { return }

        isSubmitting = true
        submitError = nil

        do {
            let orderRequest = CreateOrderRequest(
                guestCheckout: guestCheckout ? true : nil,
                clientEmail: guestCheckout ? nil : email,
                noEmail: nil,
                clientFirstName: guestCheckout ? nil : firstName,
                clientLastName: guestCheckout ? nil : (lastName.isEmpty ? nil : lastName),
                clientPhone: guestCheckout ? nil : (phone.isEmpty ? nil : phone),
                clientCountryCode: nil,
                addressLine1: nil,
                addressLine2: nil,
                city: nil,
                county: nil,
                postcode: nil,
                country: nil,
                locationId: locationId.isEmpty ? nil : locationId,
                intakeMethod: "accessories_in_store",
                readyBy: nil,
                existingTicketId: nil,
                notes: nil,
                preAuthorization: nil,
                signature: nil
            )

            let response: OrderCreateResponse = try await APIClient.shared.request(
                .createOrder, body: orderRequest
            )

            logger.info("Accessories order created: #\(response.orderNumber)")

            // Navigate to order detail via deep link handler
            DeepLinkHandler.shared.pendingDestination = .order(id: response.id)
            onComplete()

        } catch {
            logger.error("Failed to create accessories order: \(error)")
            submitError = error.localizedDescription
        }

        isSubmitting = false
    }

    // MARK: - Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }
}

// ClientSearchResponse is defined in BookingViewModel.swift

#Preview {
    NavigationStack {
        AccessoriesBookingView(onComplete: {})
    }
}
