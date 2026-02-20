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
                                    .background(device.deviceTypeId == type.id ? Color.accentColor : Color.platformGray6)
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
                        .background(Color.platformGray6)
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
                    .background(Color.platformGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Customer Reported Issues")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextEditor(text: $device.customerReportedIssues)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        .background(Color.platformBackground)
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
