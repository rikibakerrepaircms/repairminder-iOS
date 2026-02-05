# Stage 06: Add Parts

## Objective
Enable staff to add parts used during repair to the device record.

## Dependencies
`[Requires: Stage 01 complete]` - Needs API endpoints for parts

## Complexity
**Low** - Simple form with API call

---

## Files to Create

### 1. `Features/Staff/Devices/Editors/AddPartSheet.swift`
Form for adding a new part.

---

## Files to Modify

### 1. `Features/Staff/Devices/DeviceDetailView.swift`
Add "Add Part" button to parts section.

### 2. `Features/Staff/Devices/DeviceDetailViewModel.swift`
Add method to add part.

---

## Implementation Details

### AddPartSheet.swift

```swift
import SwiftUI

// MARK: - Add Part Sheet

/// Sheet for adding a part used during repair
struct AddPartSheet: View {
    let orderId: String
    let deviceId: String
    let onComplete: (DevicePart) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var partName = ""
    @State private var partSku = ""
    @State private var partCost = ""
    @State private var supplier = ""
    @State private var isOem = false
    @State private var warrantyDays = ""
    @State private var isSaving = false
    @State private var error: String?

    @FocusState private var focusedField: Field?

    enum Field {
        case name, sku, cost, supplier, warranty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Required fields
                Section("Part Details") {
                    TextField("Part Name *", text: $partName)
                        .focused($focusedField, equals: .name)

                    TextField("SKU / Part Number", text: $partSku)
                        .focused($focusedField, equals: .sku)
                        .textInputAutocapitalization(.characters)
                }

                // Cost & supplier
                Section("Pricing") {
                    HStack {
                        Text("£")
                            .foregroundStyle(.secondary)
                        TextField("Cost", text: $partCost)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .cost)
                    }

                    TextField("Supplier", text: $supplier)
                        .focused($focusedField, equals: .supplier)
                }

                // Quality & warranty
                Section("Quality") {
                    Toggle("OEM Part", isOn: $isOem)

                    HStack {
                        TextField("Warranty (days)", text: $warrantyDays)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .warranty)

                        if !warrantyDays.isEmpty, let days = Int(warrantyDays) {
                            Text(days == 1 ? "day" : "days")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Error
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Part")
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
                            Task { await addPart() }
                        }
                        .disabled(partName.isEmpty)
                    }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Button("Previous") {
                            moveFocus(direction: .previous)
                        }
                        .disabled(focusedField == .name)

                        Button("Next") {
                            moveFocus(direction: .next)
                        }
                        .disabled(focusedField == .warranty)

                        Spacer()

                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                focusedField = .name
            }
        }
    }

    // MARK: - Actions

    private func addPart() async {
        isSaving = true
        error = nil

        do {
            let request = AddDevicePartRequest(
                partName: partName,
                partSku: partSku.isEmpty ? nil : partSku,
                partCost: Double(partCost),
                supplier: supplier.isEmpty ? nil : supplier,
                isOem: isOem,
                warrantyDays: Int(warrantyDays)
            )

            let part: DevicePart = try await APIClient.shared.request(
                .addDevicePart(orderId: orderId, deviceId: deviceId),
                body: request
            )

            onComplete(part)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    private enum FocusDirection {
        case previous, next
    }

    private func moveFocus(direction: FocusDirection) {
        let fields: [Field] = [.name, .sku, .cost, .supplier, .warranty]
        guard let current = focusedField,
              let currentIndex = fields.firstIndex(of: current) else { return }

        switch direction {
        case .previous:
            if currentIndex > 0 {
                focusedField = fields[currentIndex - 1]
            }
        case .next:
            if currentIndex < fields.count - 1 {
                focusedField = fields[currentIndex + 1]
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddPartSheet(
        orderId: "order-1",
        deviceId: "device-1"
    ) { part in
        print("Added: \(part.partName)")
    }
}
```

### Update DeviceDetailView.swift - Parts Section

```swift
// Add state variable
@State private var showingAddPart = false

// Update partsSection
private func partsSection(_ device: DeviceDetail) -> some View {
    Section {
        // Existing parts list
        ForEach(device.partsUsed) { part in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(part.partName)
                        .font(.subheadline)
                    if part.isOem {
                        Text("OEM")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                HStack {
                    if let sku = part.partSku {
                        Text(sku)
                    }
                    if let supplier = part.supplier {
                        Text("·")
                        Text(supplier)
                    }
                    if let cost = part.formattedCost {
                        Spacer()
                        Text(cost)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }

        // Add part button
        Button {
            showingAddPart = true
        } label: {
            Label("Add Part", systemImage: "plus.circle.fill")
                .foregroundStyle(.blue)
        }
    } header: {
        HStack {
            Text("Parts Used")
            Spacer()
            Text("\(device.partsUsed.count)")
                .foregroundStyle(.secondary)
        }
    }
    .sheet(isPresented: $showingAddPart) {
        AddPartSheet(
            orderId: viewModel.orderId,
            deviceId: viewModel.deviceId
        ) { part in
            // Refresh device to show new part
            Task { await viewModel.refresh() }
        }
    }
}
```

### Update DeviceDetailViewModel.swift

```swift
// MARK: - Parts Management

/// Add a part to the device
func addPart(_ request: AddDevicePartRequest) async throws -> DevicePart {
    isUpdating = true
    error = nil

    do {
        let part: DevicePart = try await APIClient.shared.request(
            .addDevicePart(orderId: orderId, deviceId: deviceId),
            body: request
        )
        await refresh()
        return part
    } catch {
        self.error = error.localizedDescription
        throw error
    }
}
```

---

## Database Changes
None (backend schema already exists)

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Required field validation | Empty part name | Add button disabled |
| Basic part add | Part name only | Part created, sheet closes |
| Full part add | All fields filled | Part created with all data |
| OEM toggle | Toggle on | isOem=true in request |
| Cost formatting | Enter "25.50" | Parses as Double correctly |
| Warranty days | Enter "90" | Parses as Int correctly |
| Error handling | API failure | Error message shown |
| Refresh after add | Add part | Part appears in list |

---

## Acceptance Checklist

- [ ] AddPartSheet form created
- [ ] Part name is required
- [ ] Optional fields work correctly
- [ ] OEM toggle works
- [ ] Cost parses as decimal
- [ ] Warranty parses as integer
- [ ] Add button calls API
- [ ] Success refreshes device
- [ ] Error shows in sheet
- [ ] Part appears in list after add
- [ ] Build passes with no errors

---

## Deployment
```bash
xcodebuild -scheme "Repair Minder" -destination "generic/platform=iOS Simulator" build
```

---

## Handoff Notes
- Stage 09 will add delete functionality for parts
- The `DevicePart` model already exists in `DeviceDetail.swift`
- Parts are displayed in the existing parts section with this stage adding the "Add" button
