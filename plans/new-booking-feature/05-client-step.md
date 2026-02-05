# Stage 05: Client Step

## Objective

Create the customer search, selection, and entry form for the first wizard step.

## Dependencies

`[Requires: Stage 01 complete]` - Needs Location model and API endpoints
`[Requires: Stage 02 complete]` - Needs BookingViewModel and BookingFormData
`[Requires: Stage 04 complete]` - Needs wizard container

## Complexity

**High** - Client search, form validation, conditional address.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Booking/Steps/ClientStepView.swift` | Main client entry step |
| `Features/Staff/Booking/Components/ClientSearchView.swift` | Search input with results |

---

## Implementation Details

### ClientStepView.swift

```swift
//
//  ClientStepView.swift
//  Repair Minder
//

import SwiftUI

struct ClientStepView: View {
    @Bindable var viewModel: BookingViewModel

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

                // Email
                if !viewModel.formData.noEmail {
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

                // No Email Toggle
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

                // Phone
                FormTextField(
                    label: "Phone",
                    text: $viewModel.formData.phone,
                    placeholder: "07123 456789",
                    keyboardType: .phonePad
                )
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
                    Label("\(client.orderCount) orders", systemImage: "doc.text")
                    Label("\(client.deviceCount) devices", systemImage: "iphone")
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
        .background(Color(.systemBlue).opacity(0.1))
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
                .background(Color(.systemGray6))
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

// MARK: - Form TextField Helper

struct FormTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words
    var isRequired: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if isRequired {
                    Text("*")
                        .foregroundStyle(.red)
                }
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.6 : 1)
        }
    }
}

#Preview {
    ScrollView {
        ClientStepView(viewModel: BookingViewModel())
            .padding()
    }
}
```

### ClientSearchView.swift

```swift
//
//  ClientSearchView.swift
//  Repair Minder
//

import SwiftUI

struct ClientSearchView: View {
    @Binding var query: String
    let results: [Client]
    let isSearching: Bool
    let selectedClient: Client?
    let onSearch: (String) -> Void
    let onSelect: (Client) -> Void
    let onClear: () -> Void

    @State private var showResults = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search Existing Customers")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search by name, email, or phone", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .onChange(of: query) { _, newValue in
                        showResults = !newValue.isEmpty
                        onSearch(newValue)
                    }

                if isSearching {
                    ProgressView()
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        showResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Search Results
            if showResults && !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results) { client in
                        Button {
                            onSelect(client)
                            query = ""
                            showResults = false
                            isFocused = false
                        } label: {
                            ClientSearchResultRow(client: client)
                        }
                        .buttonStyle(.plain)

                        if client.id != results.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }

            // No results message
            if showResults && results.isEmpty && !isSearching && query.count >= 2 {
                Text("No customers found matching \"\(query)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }
}

struct ClientSearchResultRow: View {
    let client: Client

    var body: some View {
        HStack {
            // Avatar
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(client.initials)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accentColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(client.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(client.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let phone = client.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(client.orderCount) orders")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(client.deviceCount) devices")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    VStack {
        ClientSearchView(
            query: .constant("john"),
            results: [Client.sample],
            isSearching: false,
            selectedClient: nil,
            onSearch: { _ in },
            onSelect: { _ in },
            onClear: {}
        )
    }
    .padding()
}
```

---

## Database Changes

**None**

---

## Test Cases

### Test 1: Empty Search
- Search field shows placeholder
- No results displayed
- Clear button hidden

### Test 2: Search with Results
- Type 2+ characters triggers search
- Loading indicator shows during search
- Results appear below search field
- Results show name, email, phone, order count

### Test 3: Select Client
- Tap on result populates form
- Search field clears
- Selected client card appears
- Form fields become read-only (email)

### Test 4: Clear Selected Client
- Tap X on selected client card
- Form fields clear
- Search becomes available again

### Test 5: No Email Toggle
- Toggle hides email field
- Only shows for new clients (not existing)

### Test 6: Address Section
- Shows when requiresAddress is true (buyback device added)
- Required indicator shows for address fields
- Always shows if any address field has content

### Test 7: Location Selector
- Only shows if 2+ locations
- Dropdown lists all locations
- Selection updates form

### Test 8: Form Validation
- Step valid when: firstName not empty AND (email valid OR noEmail)
- Invalid email shows validation state
- Required fields have red asterisk

---

## Acceptance Checklist

- [ ] `ClientStepView.swift` created
- [ ] `ClientSearchView.swift` created
- [ ] `FormTextField` helper component
- [ ] Search input with debounced API calls
- [ ] Search results list with client info
- [ ] Client selection populates form
- [ ] Clear selected client works
- [ ] No email toggle hides email field
- [ ] Address section with required indicators
- [ ] Location selector (when multiple locations)
- [ ] Form validation displays correctly
- [ ] Previews render without error
- [ ] Project compiles without errors

---

## Deployment

```bash
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

---

## Handoff Notes

- Client data is stored in `viewModel.formData`
- Search uses `viewModel.searchClients(query:)` async method
- Selected client stored in `formData.existingClient`
- [See: Stage 06] Devices step may trigger address requirement for buyback
- FormTextField is reusable in other steps
