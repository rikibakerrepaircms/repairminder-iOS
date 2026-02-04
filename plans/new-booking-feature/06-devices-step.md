# Stage 06: Devices Step

## Objective

Create the device entry form allowing users to add multiple devices with brand, model, and issue details.

## Dependencies

`[Requires: Stage 01 complete]` - Needs Brand, DeviceModel, DeviceType models
`[Requires: Stage 02 complete]` - Needs BookingViewModel and BookingDeviceEntry
`[Requires: Stage 04 complete]` - Needs wizard container

## Complexity

**High** - Brand/model cascading selection, multiple devices, form validation.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Booking/Steps/DevicesStepView.swift` | Main devices step with list and entry |
| `Features/Booking/Components/DeviceEntryFormView.swift` | Form for adding/editing a device |
| `Features/Booking/Components/DeviceListItemView.swift` | Display added device in list |
| `Features/Booking/Components/BrandModelPicker.swift` | Cascading brand → model selection |

---

## Implementation Details

### DevicesStepView.swift

```swift
//
//  DevicesStepView.swift
//  Repair Minder
//

import SwiftUI

struct DevicesStepView: View {
    @Bindable var viewModel: BookingViewModel
    @State private var editingDevice: BookingDeviceEntry?
    @State private var showAddForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Devices")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Add the devices being booked in. You can add multiple devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Added Devices List
            if !viewModel.formData.devices.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "iphone")
                        Text("Added Devices (\(viewModel.formData.devices.count))")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    ForEach(viewModel.formData.devices) { device in
                        DeviceListItemView(
                            device: device,
                            defaultWorkflowType: viewModel.formData.serviceType == .buyback ? .buyback : .repair,
                            onEdit: {
                                editingDevice = device
                            },
                            onRemove: {
                                viewModel.removeDevice(id: device.id)
                            }
                        )
                    }
                }
            }

            // Add Device Button or Form
            if showAddForm || editingDevice != nil {
                DeviceEntryFormView(
                    viewModel: viewModel,
                    editingDevice: editingDevice,
                    defaultWorkflowType: viewModel.formData.serviceType == .buyback ? .buyback : .repair,
                    onSave: { device in
                        if editingDevice != nil {
                            viewModel.updateDevice(device)
                        } else {
                            viewModel.addDevice(device)
                        }
                        editingDevice = nil
                        showAddForm = false
                    },
                    onCancel: {
                        editingDevice = nil
                        showAddForm = false
                    }
                )
            } else {
                Button {
                    showAddForm = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Device")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Validation Message
            if viewModel.formData.devices.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Add at least one device to continue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        DevicesStepView(viewModel: BookingViewModel())
            .padding()
    }
}
```

### DeviceEntryFormView.swift

```swift
//
//  DeviceEntryFormView.swift
//  Repair Minder
//

import SwiftUI

struct DeviceEntryFormView: View {
    @Bindable var viewModel: BookingViewModel
    let editingDevice: BookingDeviceEntry?
    let defaultWorkflowType: BookingDeviceEntry.WorkflowType
    let onSave: (BookingDeviceEntry) -> Void
    let onCancel: () -> Void

    @State private var device: BookingDeviceEntry
    @State private var selectedBrand: Brand?
    @State private var models: [DeviceModel] = []
    @State private var isLoadingModels = false

    init(
        viewModel: BookingViewModel,
        editingDevice: BookingDeviceEntry?,
        defaultWorkflowType: BookingDeviceEntry.WorkflowType,
        onSave: @escaping (BookingDeviceEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.editingDevice = editingDevice
        self.defaultWorkflowType = defaultWorkflowType
        self.onSave = onSave
        self.onCancel = onCancel
        self._device = State(initialValue: editingDevice ?? BookingDeviceEntry.empty(workflowType: defaultWorkflowType))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text(editingDevice != nil ? "Edit Device" : "Add Device")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Brand & Model Selection
            BrandModelPicker(
                brands: viewModel.brands,
                selectedBrandId: $device.brandId,
                selectedModelId: $device.modelId,
                customBrand: $device.customBrand,
                customModel: $device.customModel,
                displayName: $device.displayName,
                onBrandSelected: { brand in
                    selectedBrand = brand
                    device.modelId = nil
                    device.customModel = nil
                    if let brand = brand, !brand.isCustom {
                        Task {
                            models = await viewModel.loadModels(for: brand.id)
                        }
                    } else {
                        models = []
                    }
                },
                models: models,
                isLoadingModels: viewModel.isLoadingModels
            )

            // Device Type
            if !viewModel.deviceTypes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Type")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.deviceTypes) { type in
                                Button {
                                    device.deviceTypeId = type.id
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: type.systemImage)
                                        Text(type.name)
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(device.deviceTypeId == type.id ? Color.accentColor : Color(.systemGray6))
                                    .foregroundStyle(device.deviceTypeId == type.id ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Identification
            VStack(alignment: .leading, spacing: 12) {
                Text("Identification")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    FormTextField(
                        label: "Serial Number",
                        text: $device.serialNumber,
                        placeholder: "ABC123XYZ"
                    )

                    FormTextField(
                        label: "IMEI",
                        text: $device.imei,
                        placeholder: "123456789012345",
                        keyboardType: .numberPad
                    )
                }

                HStack(spacing: 12) {
                    FormTextField(
                        label: "Colour",
                        text: $device.colour,
                        placeholder: "Black"
                    )

                    FormTextField(
                        label: "Storage",
                        text: $device.storageCapacity,
                        placeholder: "256GB"
                    )
                }
            }

            // Security
            VStack(alignment: .leading, spacing: 12) {
                Text("Security")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Passcode Type")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Passcode Type", selection: $device.passcodeType) {
                            ForEach(BookingDeviceEntry.PasscodeType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if device.passcodeType != .none {
                        FormTextField(
                            label: "Passcode",
                            text: $device.passcode,
                            placeholder: "****"
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Find My Status")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Find My", selection: $device.findMyStatus) {
                        ForEach(BookingDeviceEntry.FindMyStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // Condition & Issues
            VStack(alignment: .leading, spacing: 12) {
                Text("Condition")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Condition Grade")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Condition", selection: $device.conditionGrade) {
                        ForEach(BookingDeviceEntry.ConditionGrade.allCases) { grade in
                            Text(grade.displayName).tag(grade)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Customer Reported Issues")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextEditor(text: $device.customerReportedIssues)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Workflow Type (for mixed repair/buyback)
            if viewModel.formData.serviceType == .repair {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Workflow")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Workflow", selection: $device.workflowType) {
                        ForEach(BookingDeviceEntry.WorkflowType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // Save Button
            Button {
                onSave(device)
            } label: {
                Text(editingDevice != nil ? "Update Device" : "Add Device")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValid ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValid)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    private var isValid: Bool {
        !device.displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

#Preview {
    ScrollView {
        DeviceEntryFormView(
            viewModel: BookingViewModel(),
            editingDevice: nil,
            defaultWorkflowType: .repair,
            onSave: { _ in },
            onCancel: {}
        )
        .padding()
    }
}
```

### DeviceListItemView.swift

```swift
//
//  DeviceListItemView.swift
//  Repair Minder
//

import SwiftUI

struct DeviceListItemView: View {
    let device: BookingDeviceEntry
    let defaultWorkflowType: BookingDeviceEntry.WorkflowType
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Circle()
                .fill(workflowColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: workflowIcon)
                        .foregroundStyle(workflowColor)
                }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(device.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if device.workflowType != defaultWorkflowType {
                        Text(device.workflowType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(workflowColor.opacity(0.1))
                            .foregroundStyle(workflowColor)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if !device.serialNumber.isEmpty {
                        Label(device.serialNumber, systemImage: "barcode")
                    }
                    if !device.colour.isEmpty {
                        Label(device.colour, systemImage: "paintpalette")
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
            }

            Spacer()

            // Actions
            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                        .padding(8)
                }

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .padding(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var workflowColor: Color {
        device.workflowType == .buyback ? .green : .blue
    }

    private var workflowIcon: String {
        device.workflowType == .buyback ? "sterlingsign.circle" : "wrench.and.screwdriver"
    }
}

#Preview {
    VStack {
        DeviceListItemView(
            device: BookingDeviceEntry(
                id: UUID(),
                brandId: nil,
                modelId: nil,
                customBrand: nil,
                customModel: nil,
                displayName: "iPhone 14 Pro Max",
                serialNumber: "ABC123",
                imei: "",
                colour: "Black",
                storageCapacity: "256GB",
                passcode: "1234",
                passcodeType: .pin4,
                findMyStatus: .off,
                conditionGrade: .good,
                customerReportedIssues: "Screen cracked, battery drains quickly",
                deviceTypeId: nil,
                workflowType: .repair
            ),
            defaultWorkflowType: .repair,
            onEdit: {},
            onRemove: {}
        )
    }
    .padding()
}
```

### BrandModelPicker.swift

```swift
//
//  BrandModelPicker.swift
//  Repair Minder
//

import SwiftUI

struct BrandModelPicker: View {
    let brands: [Brand]
    @Binding var selectedBrandId: String?
    @Binding var selectedModelId: String?
    @Binding var customBrand: String?
    @Binding var customModel: String?
    @Binding var displayName: String
    let onBrandSelected: (Brand?) -> Void
    let models: [DeviceModel]
    let isLoadingModels: Bool

    private var selectedBrand: Brand? {
        brands.first { $0.id == selectedBrandId }
    }

    private var selectedModel: DeviceModel? {
        models.first { $0.id == selectedModelId }
    }

    private var isCustomBrand: Bool {
        selectedBrand?.isCustom == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Brand Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Brand")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Menu {
                    ForEach(brands) { brand in
                        Button {
                            selectedBrandId = brand.id
                            onBrandSelected(brand)
                            updateDisplayName()
                        } label: {
                            HStack {
                                Text(brand.name)
                                if selectedBrandId == brand.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedBrand?.name ?? "Select brand...")
                            .foregroundStyle(selectedBrandId == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Custom Brand Input
            if isCustomBrand {
                FormTextField(
                    label: "Custom Brand Name",
                    text: Binding(
                        get: { customBrand ?? "" },
                        set: {
                            customBrand = $0
                            updateDisplayName()
                        }
                    ),
                    placeholder: "Enter brand name"
                )
            }

            // Model Picker (if brand selected and not custom)
            if selectedBrandId != nil && !isCustomBrand {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Model")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if isLoadingModels {
                        HStack {
                            ProgressView()
                            Text("Loading models...")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Menu {
                            ForEach(models) { model in
                                Button {
                                    selectedModelId = model.id
                                    updateDisplayName()
                                } label: {
                                    HStack {
                                        Text(model.name)
                                        if selectedModelId == model.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }

                            Divider()

                            Button {
                                selectedModelId = nil
                                customModel = ""
                            } label: {
                                Text("Other / Custom")
                            }
                        } label: {
                            HStack {
                                Text(selectedModel?.name ?? (customModel?.isEmpty == false ? customModel! : "Select model..."))
                                    .foregroundStyle(selectedModelId == nil && (customModel?.isEmpty ?? true) ? .secondary : .primary)
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
            }

            // Custom Model Input
            if isCustomBrand || (selectedBrandId != nil && selectedModelId == nil && !models.isEmpty) {
                FormTextField(
                    label: "Custom Model Name",
                    text: Binding(
                        get: { customModel ?? "" },
                        set: {
                            customModel = $0
                            updateDisplayName()
                        }
                    ),
                    placeholder: "Enter model name"
                )
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

    private func updateDisplayName() {
        var parts: [String] = []

        if let brand = selectedBrand, !brand.isCustom {
            parts.append(brand.name)
        } else if let custom = customBrand, !custom.isEmpty {
            parts.append(custom)
        }

        if let model = selectedModel {
            parts.append(model.name)
        } else if let custom = customModel, !custom.isEmpty {
            parts.append(custom)
        }

        if !parts.isEmpty {
            displayName = parts.joined(separator: " ")
        }
    }
}

#Preview {
    BrandModelPicker(
        brands: Brand.sampleList,
        selectedBrandId: .constant(nil),
        selectedModelId: .constant(nil),
        customBrand: .constant(nil),
        customModel: .constant(nil),
        displayName: .constant(""),
        onBrandSelected: { _ in },
        models: [],
        isLoadingModels: false
    )
    .padding()
}
```

---

## Database Changes

**None**

---

## Test Cases

### Test 1: Empty State
- Shows "Add Device" button
- Validation message displayed
- Step is invalid (no devices)

### Test 2: Add Device Flow
- Tap "Add Device" shows form
- Form has brand/model picker
- Form has all device fields
- Cancel returns to empty state

### Test 3: Brand/Model Selection
- Select brand loads models
- Select model updates display name
- "Other" option allows custom entry
- Custom brand shows custom input

### Test 4: Save Device
- Valid device (display name) can be saved
- Device appears in list
- Form closes
- Can add another device

### Test 5: Edit Device
- Tap edit on device list item
- Form populates with device data
- Save updates device
- Cancel discards changes

### Test 6: Remove Device
- Tap trash on device list item
- Device removed from list
- Step becomes invalid if no devices left

### Test 7: Multiple Devices
- Can add multiple devices
- Count updates in header
- All devices shown in list

---

## Acceptance Checklist

- [ ] `DevicesStepView.swift` created
- [ ] `DeviceEntryFormView.swift` created
- [ ] `DeviceListItemView.swift` created
- [ ] `BrandModelPicker.swift` created
- [ ] Brand dropdown with API data
- [ ] Model dropdown loads on brand select
- [ ] Custom brand/model input works
- [ ] Device type selection works
- [ ] All device fields editable
- [ ] Add device saves to list
- [ ] Edit device updates list
- [ ] Remove device works
- [ ] Multiple devices supported
- [ ] Validation message shows when empty
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

- Devices stored in `viewModel.formData.devices`
- Each device has unique UUID for identification
- BrandModelPicker handles cascading selection
- Workflow type can be mixed (repair + buyback on same order)
- [See: Stage 07] Summary will display all added devices
- [See: Stage 05] Adding buyback device triggers address requirement
