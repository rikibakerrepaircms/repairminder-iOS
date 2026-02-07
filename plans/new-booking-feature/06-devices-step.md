# Stage 06: Devices Step

## Objective

Create the device entry form allowing users to add multiple devices with brand, model, and issue details.

## Dependencies

`[Requires: Stage 01 complete]` - Needs DeviceSearchResult, DeviceType models and `.deviceSearch(query:)` endpoint
`[Requires: Stage 02 complete]` - Needs BookingViewModel and BookingDeviceEntry
`[Requires: Stage 04 complete]` - Needs wizard container

## Complexity

**High** - Unified device search (brand + model), multiple devices, form validation.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Booking/Steps/DevicesStepView.swift` | Main devices step with list and entry |
| `Features/Staff/Booking/Components/DeviceEntryFormView.swift` | Form for adding/editing a device |
| `Features/Staff/Booking/Components/DeviceListItemView.swift` | Display added device in list |
| `Features/Staff/Booking/Components/DeviceSearchPicker.swift` | Unified brand/model search using `/api/device-search` |

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
    @State private var deviceSearchQuery: String = ""

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

            // Brand & Model Selection (unified search)
            DeviceSearchPicker(
                viewModel: viewModel,
                selectedBrandId: $device.brandId,
                selectedModelId: $device.modelId,
                customBrand: $device.customBrand,
                customModel: $device.customModel,
                displayName: $device.displayName
            )

            // Device Type
            // Device types: only show custom (non-system) types.
            // System types like "Repair" and "Buyback" are workflow markers,
            // not user-selectable categories.
            let selectableTypes = viewModel.deviceTypes.filter { $0.isSystem != true }
            if !selectableTypes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Type")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectableTypes) { type in
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

                    if device.passcodeType != .none && device.passcodeType != .biometric {
                        FormTextField(
                            label: device.passcodeType == .pin ? "PIN Code" : "Passcode",
                            text: $device.passcode,
                            placeholder: device.passcodeType == .pin ? "1234" : "****"
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
                    .pickerStyle(.menu)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
            // Only shown for repair orders — allows marking individual devices as buyback.
            // For buyback orders, all devices default to .buyback (no picker needed).
            // Backend accepts workflow_type per device (device_handlers.js line 1048).
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

            // Accessories
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Accessories Included")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        device.accessories.append(BookingAccessoryItem.empty())
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                            .font(.caption)
                    }
                }

                if !device.accessories.isEmpty {
                    ForEach($device.accessories) { $accessory in
                        HStack(spacing: 8) {
                            Picker("Type", selection: $accessory.accessoryType) {
                                Text("Charger").tag("charger")
                                Text("Cable").tag("cable")
                                Text("Case").tag("case")
                                Text("SIM Card").tag("sim_card")
                                Text("Box").tag("box")
                                Text("Other").tag("other")
                            }
                            .pickerStyle(.menu)

                            TextField("Description (optional)", text: $accessory.description)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                device.accessories.removeAll { $0.id == accessory.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
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
        let hasDisplayName = !device.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        let hasBrandOrCustomBrand = device.brandId != nil || !(device.customBrand ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        return hasDisplayName && hasBrandOrCustomBrand
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

                if !device.accessories.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bag")
                        Text("\(device.accessories.count) accessor\(device.accessories.count == 1 ? "y" : "ies")")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        device.workflowType == .buyback ? "arrow.triangle.2.circlepath" : "wrench.and.screwdriver"
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
                passcodeType: .pin,
                findMyStatus: .disabled,
                conditionGrade: .b,
                customerReportedIssues: "Screen cracked, battery drains quickly",
                deviceTypeId: nil,
                workflowType: .repair,
                accessories: []
            ),
            defaultWorkflowType: .repair,
            onEdit: {},
            onRemove: {}
        )
    }
    .padding()
}
```

### DeviceSearchPicker.swift

Uses the unified `/api/device-search?q=<query>` endpoint. User types a search query (e.g. "iPhone 14") and sees matching brands and models. Selecting a result populates brandId/modelId and updates the display name. User can also type a custom brand/model if no match found.

> **Optional enhancement:** The backend also supports an optional `category` query parameter (e.g. `?q=iPhone&category=phone`) to filter results by device category. This is not used in the initial implementation but could be added later to pre-filter results when a device type is already selected.

```swift
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
                        .textInputAutocapitalization(.never)
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
                .background(Color(.systemGray6))
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
                .background(Color(.systemBackground))
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

### Test 3: Device Search
- Type 2+ characters triggers API search
- Results show matching models and brands
- Selecting a model sets brandId, modelId, and displayName
- Selecting a brand sets brandId and displayName
- Custom brand/model inputs shown when no result selected

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
- [ ] `DeviceSearchPicker.swift` created
- [ ] Device search calls `/api/device-search?q=` via `.deviceSearch(query:)`
- [ ] Search results show matching brands and models
- [ ] Selecting result populates brandId/modelId/displayName
- [ ] Custom brand/model input works when no result selected
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
- `DeviceSearchPicker` uses unified `/api/device-search?q=` — no separate brand/model endpoints
- Workflow type can be mixed (repair + buyback on same order) — picker only shown for repair service type orders
- Backend `/api/device-search` also accepts optional `category` param — not used initially but available for future enhancement
- [See: Stage 07] Summary will display all added devices
- [See: Stage 05] Adding buyback device triggers address requirement
