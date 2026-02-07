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
                    .foregroundStyle(Color.accentColor)
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
