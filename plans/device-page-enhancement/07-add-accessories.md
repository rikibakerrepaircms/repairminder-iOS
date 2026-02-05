# Stage 07: Add Accessories

## Objective
Enable staff to add accessories received with a device and mark them as returned.

## Dependencies
`[Requires: Stage 01 complete]` - Needs API endpoints for accessories

## Complexity
**Low** - Simple form with type picker and return action

---

## Files to Create

### 1. `Features/Staff/Devices/Editors/AddAccessorySheet.swift`
Form for adding a new accessory.

---

## Files to Modify

### 1. `Features/Staff/Devices/DeviceDetailView.swift`
Add "Add Accessory" button and "Mark Returned" swipe action.

### 2. `Features/Staff/Devices/DeviceDetailViewModel.swift`
Add methods for accessory operations.

---

## Implementation Details

### AddAccessorySheet.swift

```swift
import SwiftUI

// MARK: - Add Accessory Sheet

/// Sheet for adding an accessory received with a device
struct AddAccessorySheet: View {
    let orderId: String
    let deviceId: String
    let onComplete: (DeviceAccessory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: AccessoryType = .charger
    @State private var description = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                // Accessory type
                Section("Type") {
                    Picker("Accessory Type", selection: $selectedType) {
                        ForEach(AccessoryType.allCases, id: \.self) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Description (for "other" type especially)
                Section("Description") {
                    TextField("Additional details (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Error
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Accessory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task { await addAccessory() }
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func addAccessory() async {
        isSaving = true
        error = nil

        do {
            let request = AddDeviceAccessoryRequest(
                accessoryType: selectedType.rawValue,
                description: description.isEmpty ? nil : description
            )

            let accessory: DeviceAccessory = try await APIClient.shared.request(
                .addDeviceAccessory(orderId: orderId, deviceId: deviceId),
                body: request
            )

            onComplete(accessory)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    AddAccessorySheet(
        orderId: "order-1",
        deviceId: "device-1"
    ) { accessory in
        print("Added: \(accessory.typeDisplayName)")
    }
}
```

### Update DeviceDetailView.swift - Accessories Section

```swift
// Add state variable
@State private var showingAddAccessory = false

// Update accessoriesSection
private func accessoriesSection(_ device: DeviceDetail) -> some View {
    Section {
        ForEach(device.accessories) { accessory in
            accessoryRow(accessory)
                .swipeActions(edge: .trailing) {
                    if !accessory.isReturned {
                        Button {
                            Task {
                                await viewModel.returnAccessory(accessory.id)
                            }
                        } label: {
                            Label("Returned", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
                }
        }

        // Add accessory button
        Button {
            showingAddAccessory = true
        } label: {
            Label("Add Accessory", systemImage: "plus.circle.fill")
                .foregroundStyle(.blue)
        }
    } header: {
        HStack {
            Text("Accessories")
            Spacer()
            Text("\(device.accessories.count)")
                .foregroundStyle(.secondary)
        }
    }
    .sheet(isPresented: $showingAddAccessory) {
        AddAccessorySheet(
            orderId: viewModel.orderId,
            deviceId: viewModel.deviceId
        ) { accessory in
            Task { await viewModel.refresh() }
        }
    }
}

@ViewBuilder
private func accessoryRow(_ accessory: DeviceAccessory) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(accessory.typeDisplayName)
                    .font(.subheadline)

                if accessory.isReturned {
                    Text("Returned")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if let description = accessory.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Spacer()

        if accessory.isReturned {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }
}
```

### Update DeviceDetailViewModel.swift

```swift
// MARK: - Accessories Management

/// Add an accessory to the device
func addAccessory(_ request: AddDeviceAccessoryRequest) async throws -> DeviceAccessory {
    isUpdating = true
    error = nil

    do {
        let accessory: DeviceAccessory = try await APIClient.shared.request(
            .addDeviceAccessory(orderId: orderId, deviceId: deviceId),
            body: request
        )
        await refresh()
        return accessory
    } catch {
        self.error = error.localizedDescription
        throw error
    }
}

/// Mark an accessory as returned
func returnAccessory(_ accessoryId: String) async {
    isUpdating = true
    error = nil

    do {
        try await APIClient.shared.requestVoid(
            .returnDeviceAccessory(orderId: orderId, deviceId: deviceId, accessoryId: accessoryId)
        )
        await refresh()
        successMessage = "Accessory marked as returned"
    } catch {
        self.error = error.localizedDescription
    }

    isUpdating = false
}
```

---

## Database Changes
None (backend schema already exists)

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Add charger | Select "Charger", no description | Accessory created |
| Add with description | Type + description | Both saved |
| Add "Other" type | Select "Other" | Works correctly |
| Mark returned | Swipe left, tap Returned | Green badge shows |
| Return already returned | N/A | Swipe action not shown |
| Error handling | API failure | Error message shown |
| Refresh after add | Add accessory | Appears in list |

---

## Acceptance Checklist

- [ ] AddAccessorySheet form created
- [ ] Type picker shows all accessory types
- [ ] Description field is optional
- [ ] Add button calls API
- [ ] Swipe action marks as returned
- [ ] Returned badge shows correctly
- [ ] Returned items don't show swipe action
- [ ] Success refreshes device
- [ ] Error shows in sheet
- [ ] Build passes with no errors

---

## Deployment
```bash
xcodebuild -scheme "Repair Minder" -destination "generic/platform=iOS Simulator" build
```

---

## Handoff Notes
- Stage 09 will add delete functionality for accessories
- Accessory types are defined in `DeviceAccessoryModels.swift` from Stage 01
- The swipe action uses the green tint to indicate positive action
