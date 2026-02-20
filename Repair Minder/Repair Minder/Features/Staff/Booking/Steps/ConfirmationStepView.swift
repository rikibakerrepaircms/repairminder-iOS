//
//  ConfirmationStepView.swift
//  Repair Minder
//

import SwiftUI

struct ConfirmationStepView: View {
    @Bindable var viewModel: BookingViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 90, height: 90)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
            }

            // Success Message
            VStack(spacing: 8) {
                Text("Booking Complete!")
                    .font(.title)
                    .fontWeight(.bold)

                if let orderNumber = viewModel.formData.createdOrderNumber {
                    Text(verbatim: "Order #\(orderNumber)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }

            // Order Summary
            VStack(spacing: 16) {
                ConfirmationSummaryRow(
                    icon: "person.fill",
                    label: "Customer",
                    value: viewModel.formData.clientDisplayName
                )

                ConfirmationSummaryRow(
                    icon: "iphone",
                    label: "Devices",
                    value: "\(viewModel.formData.devices.count) device\(viewModel.formData.devices.count != 1 ? "s" : "")"
                )

                if viewModel.formData.readyByDate != nil {
                    ConfirmationSummaryRow(
                        icon: "calendar",
                        label: "Ready By",
                        value: formattedReadyBy
                    )
                }

                ConfirmationSummaryRow(
                    icon: "tag.fill",
                    label: "Service Type",
                    value: viewModel.formData.serviceType.title
                )
            }
            .padding()
            .background(Color.platformGray6)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            // Action Buttons
            VStack(spacing: 12) {
                // View Order Button
                if let orderId = viewModel.formData.createdOrderId {
                    Button {
                        DeepLinkHandler.shared.pendingDestination = .order(id: orderId)
                        onComplete()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("View Order")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // New Booking Button
                Button {
                    viewModel.reset()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Booking")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.platformGray5)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Done Button
                Button {
                    onComplete()
                } label: {
                    Text("Done")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }

    private var formattedReadyBy: String {
        guard let date = viewModel.formData.readyByDate else { return "" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        var result = formatter.string(from: date)

        if let time = viewModel.formData.readyByTime {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            result += " at \(timeFormatter.string(from: time))"
        }

        return result
    }
}

// MARK: - Confirmation Summary Row

struct ConfirmationSummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    ConfirmationStepView(
        viewModel: {
            let vm = BookingViewModel()
            vm.formData.firstName = "John"
            vm.formData.lastName = "Smith"
            vm.formData.createdOrderId = "order-123"
            vm.formData.createdOrderNumber = 12345
            vm.formData.devices = [
                BookingDeviceEntry.empty(),
                BookingDeviceEntry.empty()
            ]
            return vm
        }(),
        onComplete: {}
    )
}
