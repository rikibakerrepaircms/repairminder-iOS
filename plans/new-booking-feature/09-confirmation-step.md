# Stage 09: Confirmation Step

## Objective

Create the success confirmation view showing order details after successful booking creation.

## Dependencies

`[Requires: Stage 02 complete]` - Needs BookingViewModel and BookingFormData
`[Requires: Stage 04 complete]` - Needs wizard container

## Complexity

**Low** - Static display with action buttons.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Booking/Steps/ConfirmationStepView.swift` | Success view with order details |

---

## Implementation Details

### ConfirmationStepView.swift

```swift
//
//  ConfirmationStepView.swift
//  Repair Minder
//

import SwiftUI

struct ConfirmationStepView: View {
    @Bindable var viewModel: BookingViewModel
    let onDismiss: () -> Void

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
                    Text("Order #\(orderNumber)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accentColor)
                }
            }

            // Order Summary
            VStack(spacing: 16) {
                SummaryRow(
                    icon: "person.fill",
                    label: "Customer",
                    value: viewModel.formData.clientDisplayName
                )

                SummaryRow(
                    icon: "iphone",
                    label: "Devices",
                    value: "\(viewModel.formData.devices.count) device\(viewModel.formData.devices.count != 1 ? "s" : "")"
                )

                if viewModel.formData.readyByDate != nil {
                    SummaryRow(
                        icon: "calendar",
                        label: "Ready By",
                        value: formattedReadyBy
                    )
                }

                SummaryRow(
                    icon: "tag.fill",
                    label: "Service Type",
                    value: viewModel.formData.serviceType.title
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            // Action Buttons
            VStack(spacing: 12) {
                // View Order Button
                if let orderId = viewModel.formData.createdOrderId {
                    Button {
                        // Navigate to order detail
                        // For now, just dismiss
                        onDismiss()
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
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Done Button
                Button {
                    onDismiss()
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

// MARK: - Summary Row

struct SummaryRow: View {
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
        onDismiss: {}
    )
}
```

---

## Database Changes

**None**

---

## Test Cases

### Test 1: Success Display
- Green checkmark icon displayed
- "Booking Complete!" text shown
- Order number displayed prominently

### Test 2: Order Summary
- Customer name shown
- Device count shown
- Ready-by date shown (if set)
- Service type shown

### Test 3: View Order Button
- Visible when orderId exists
- Taps dismiss wizard (future: navigate to order)

### Test 4: New Booking Button
- Resets form and goes back to step 1
- All form data cleared

### Test 5: Done Button
- Dismisses entire wizard
- Returns to dashboard

---

## Acceptance Checklist

- [ ] `ConfirmationStepView.swift` created
- [ ] Success checkmark animation/icon
- [ ] Order number displayed
- [ ] Summary shows key booking info
- [ ] "View Order" button present
- [ ] "New Booking" resets wizard
- [ ] "Done" dismisses wizard
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

- This is the final step after successful submission
- Order ID and number come from API response stored in formData
- "New Booking" calls `viewModel.reset()` to start fresh
- [See: Stage 10] Dashboard will launch BookingView
- Future: "View Order" could navigate to OrderDetailView
