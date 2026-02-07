# Stage 07: Summary Step

## Objective

Create the review step displaying all entered information with ready-by date selection.

## Dependencies

`[Requires: Stage 02 complete]` - Needs BookingViewModel and BookingFormData
`[Requires: Stage 04 complete]` - Needs wizard container
`[Requires: Stage 05 complete]` - Needs `FormTextField` component (defined in ClientStepView.swift, used here for pre-auth fields)

## Complexity

**Low** - Display-only with date picker.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Booking/Steps/SummaryStepView.swift` | Summary/review step |

---

## Implementation Details

### SummaryStepView.swift

```swift
//
//  SummaryStepView.swift
//  Repair Minder
//

import SwiftUI

struct SummaryStepView: View {
    @Bindable var viewModel: BookingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Summary")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Review the booking details before proceeding.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Customer Section
            BookingSummarySection(
                title: "Customer",
                icon: "person.fill",
                onEdit: { viewModel.goToStep(.client) }
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.formData.clientDisplayName)
                        .font(.headline)

                    if !viewModel.formData.noEmail {
                        Label(viewModel.formData.email, systemImage: "envelope")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("No email address", systemImage: "envelope.badge.shield.half.filled")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    if !viewModel.formData.phone.isEmpty {
                        Label(viewModel.formData.phone, systemImage: "phone")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !viewModel.formData.addressLine1.isEmpty {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.formData.addressLine1)
                                if !viewModel.formData.addressLine2.isEmpty {
                                    Text(viewModel.formData.addressLine2)
                                }
                                Text("\(viewModel.formData.city), \(viewModel.formData.postcode)")
                            }
                        } icon: {
                            Image(systemName: "mappin.circle")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            // Devices Section
            BookingSummarySection(
                title: "Devices (\(viewModel.formData.devices.count))",
                icon: "iphone",
                onEdit: { viewModel.goToStep(.devices) }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.formData.devices) { device in
                        DeviceSummaryCard(device: device)
                    }
                }
            }

            // Location Section (if set)
            if let location = viewModel.locations.first(where: { $0.id == viewModel.formData.locationId }) {
                BookingSummarySection(
                    title: "Location",
                    icon: "building.2",
                    onEdit: { viewModel.goToStep(.client) }
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if !location.fullAddress.isEmpty {
                            Text(location.fullAddress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Internal Notes (Optional)
            VStack(alignment: .leading, spacing: 16) {
                Text("Internal Notes (Optional)")
                    .font(.headline)

                Text("Staff-only notes added to the ticket. Not visible to the customer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("e.g. Customer mentioned they need it back by Friday", text: $viewModel.formData.internalNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Divider()

            // Ready By Date/Time
            VStack(alignment: .leading, spacing: 16) {
                Text("Ready By (Optional)")
                    .font(.headline)

                Text("Set an expected completion date for the customer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { viewModel.formData.readyByDate ?? Date().addingTimeInterval(86400 * 3) },
                        set: { viewModel.formData.readyByDate = $0 }
                    ),
                    in: Date()...,
                    displayedComponents: .date
                )

                if viewModel.formData.readyByDate != nil {
                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: { viewModel.formData.readyByTime ?? defaultTime },
                            set: { viewModel.formData.readyByTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    Button {
                        viewModel.formData.readyByDate = nil
                        viewModel.formData.readyByTime = nil
                    } label: {
                        Text("Clear ready-by date")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Pre-authorisation (Optional)
            VStack(alignment: .leading, spacing: 16) {
                Text("Pre-authorisation (Optional)")
                    .font(.headline)

                Text("Set a diagnostic or assessment fee the customer agrees to upfront.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Enable pre-authorisation", isOn: $viewModel.formData.preAuthEnabled)
                    .tint(.accentColor)

                if viewModel.formData.preAuthEnabled {
                    FormTextField(
                        label: "Amount",
                        text: $viewModel.formData.preAuthAmount,
                        placeholder: "0.00",
                        keyboardType: .decimalPad
                    )

                    FormTextField(
                        label: "Notes (optional)",
                        text: $viewModel.formData.preAuthNotes,
                        placeholder: "e.g. Diagnostic fee"
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var defaultTime: Date {
        // Default to 5 PM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 17
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - Booking Summary Section

struct BookingSummarySection<Content: View>: View {
    let title: String
    let icon: String
    let onEdit: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Text("Edit")
                        .font(.caption)
                        .foregroundStyle(.accentColor)
                }
            }

            content
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Device Summary Card

struct DeviceSummaryCard: View {
    let device: BookingDeviceEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: deviceIcon)
                .foregroundStyle(workflowColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(device.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(device.workflowType.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(workflowColor.opacity(0.1))
                        .foregroundStyle(workflowColor)
                        .clipShape(Capsule())
                }

                HStack(spacing: 12) {
                    if !device.serialNumber.isEmpty {
                        Text("S/N: \(device.serialNumber)")
                    }
                    if !device.colour.isEmpty {
                        Text(device.colour)
                    }
                    if !device.storageCapacity.isEmpty {
                        Text(device.storageCapacity)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !device.customerReportedIssues.isEmpty {
                    Text(device.customerReportedIssues)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Label(device.conditionGrade.displayName, systemImage: "star")
                    if device.findMyStatus != .unknown {
                        Label("Find My: \(device.findMyStatus.displayName)", systemImage: "location.fill")
                    }
                    if device.passcodeType != .none {
                        Label("Passcode", systemImage: "lock.fill")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if !device.accessories.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bag")
                        Text("Accessories: \(device.accessories.map(\.accessoryType).joined(separator: ", "))")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var workflowColor: Color {
        device.workflowType == .buyback ? .green : .blue
    }

    private var deviceIcon: String {
        device.workflowType == .buyback ? "arrow.triangle.2.circlepath" : "wrench.and.screwdriver"
    }
}

#Preview {
    ScrollView {
        SummaryStepView(viewModel: {
            let vm = BookingViewModel()
            vm.formData.firstName = "John"
            vm.formData.lastName = "Smith"
            vm.formData.email = "john@example.com"
            vm.formData.phone = "07123456789"
            vm.formData.devices = [
                BookingDeviceEntry(
                    id: UUID(),
                    brandId: nil,
                    modelId: nil,
                    customBrand: nil,
                    customModel: nil,
                    displayName: "iPhone 14 Pro",
                    serialNumber: "ABC123",
                    imei: "",
                    colour: "Black",
                    storageCapacity: "256GB",
                    passcode: "",
                    passcodeType: .none,
                    findMyStatus: .disabled,
                    conditionGrade: .b,
                    customerReportedIssues: "Cracked screen",
                    deviceTypeId: nil,
                    workflowType: .repair,
                    accessories: []
                )
            ]
            return vm
        }())
        .padding()
    }
}
```

---

## Database Changes

**None**

---

## Test Cases

### Test 1: Customer Display
- Shows customer name prominently
- Shows email (or "No email" indicator)
- Shows phone if provided
- Shows address if provided

### Test 2: Devices Display
- Shows device count in header
- Each device shows:
  - Display name
  - Workflow type badge
  - Serial/colour/storage
  - Issues (truncated)
  - Condition grade

### Test 3: Internal Notes
- Text field is editable
- Multiline input works (3-6 lines)
- Placeholder text shows when empty
- Notes persist when navigating away and back

### Test 4: Location Display
- Shows selected location name
- Shows location address

### Test 5: Edit Navigation
- Tap "Edit" on customer goes to client step
- Tap "Edit" on devices goes to devices step
- Tap "Edit" on location goes to client step

### Test 6: Ready-By Date
- Date picker defaults to 3 days out
- Selecting date shows time picker
- Time defaults to 5 PM
- "Clear" button removes date
- Step always valid (optional field)

### Test 7: Pre-authorisation
- Toggle is off by default
- Enabling shows amount and notes fields
- Amount accepts decimal input
- Notes is optional
- Step always valid (optional feature)

---

## Acceptance Checklist

- [ ] `SummaryStepView.swift` created
- [ ] Customer section with all details
- [ ] Devices section with all devices listed
- [ ] Location section (when selected)
- [ ] Internal notes text field (multiline, editable)
- [ ] Edit buttons navigate to correct steps
- [ ] Ready-by date picker works
- [ ] Ready-by time picker shows when date set
- [ ] Clear button removes ready-by
- [ ] Pre-authorisation toggle and fields
- [ ] Amount and notes fields shown when enabled
- [ ] Preview renders with sample data
- [ ] Project compiles without errors

---

## Deployment

```bash
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

---

## Handoff Notes

- Summary is read-only except for ready-by date, internal notes, and pre-auth fields
- Edit buttons use `viewModel.goToStep()` to navigate back
- All data comes from `viewModel.formData`
- [See: Stage 08] Signature step comes next
- Ready-by date/time combined in submit
