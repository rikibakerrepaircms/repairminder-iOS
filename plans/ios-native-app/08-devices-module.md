# Stage 08: Devices Module

## Objective

Build device list and detail views with status management, diagnosis entry, and assignment capabilities.

---

## Dependencies

**Requires:** [See: Stage 07] complete - Order detail shows devices

---

## Complexity

**Medium** - Similar pattern to Orders, additional device-specific fields

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Devices/DeviceListView.swift` | My Queue / All devices list |
| `Features/Devices/DeviceListViewModel.swift` | List logic |
| `Features/Devices/DeviceDetailView.swift` | Device detail & editing |
| `Features/Devices/DeviceDetailViewModel.swift` | Detail logic |
| `Features/Devices/Components/DiagnosisForm.swift` | Diagnosis entry |
| `Features/Devices/Components/DeviceInfoCard.swift` | Device specs display |

---

## Implementation Details

### Key Features

1. **My Queue View** - Devices assigned to current user
2. **Device Detail** - Full device information
3. **Status Updates** - Change device status through workflow
4. **Diagnosis Entry** - Add diagnosis and resolution notes
5. **Price Update** - Set repair price (with approval workflow)

### Device Detail View Structure

```swift
struct DeviceDetailView: View {
    let deviceId: String
    @StateObject private var viewModel: DeviceDetailViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Device Header (type, brand, model)
                DeviceHeaderCard(device: viewModel.device)

                // Status Actions (workflow buttons)
                DeviceStatusActions(
                    currentStatus: viewModel.device?.status ?? .bookedIn,
                    onStatusChange: viewModel.updateStatus
                )

                // Device Info (serial, IMEI, passcode)
                DeviceInfoCard(device: viewModel.device)

                // Issue Description
                IssueCard(issue: viewModel.device?.issue)

                // Diagnosis Form (editable)
                DiagnosisForm(
                    diagnosis: $viewModel.diagnosis,
                    resolution: $viewModel.resolution,
                    onSave: viewModel.saveDiagnosis
                )

                // Pricing
                PricingCard(
                    price: viewModel.device?.price,
                    onPriceUpdate: viewModel.updatePrice
                )

                // Order Link
                if let orderId = viewModel.device?.orderId {
                    OrderLinkCard(orderId: orderId)
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.device?.displayName ?? "Device")
    }
}
```

### Device Status Workflow

```swift
extension DeviceStatus {
    var nextStatuses: [DeviceStatus] {
        switch self {
        case .bookedIn:
            return [.diagnosing]
        case .diagnosing:
            return [.awaitingApproval, .unrepairable]
        case .awaitingApproval:
            return [.approved]
        case .approved:
            return [.inRepair, .awaitingParts]
        case .inRepair:
            return [.awaitingParts, .repaired]
        case .awaitingParts:
            return [.inRepair]
        case .repaired:
            return [.qualityCheck]
        case .qualityCheck:
            return [.ready, .inRepair]
        case .ready, .collected, .unrepairable:
            return []
        }
    }
}
```

---

## Test Cases

| Test | Expected |
|------|----------|
| My queue loads | Shows assigned devices |
| Device detail loads | All info displayed |
| Status update | Status changes, syncs |
| Diagnosis save | Text persisted |
| Price update | Price saved |
| Navigate to order | Opens order detail |

---

## Acceptance Checklist

- [ ] My Queue shows assigned devices
- [ ] Device detail displays all fields
- [ ] Status workflow buttons correct
- [ ] Diagnosis form saves
- [ ] Resolution form saves
- [ ] Price updates work
- [ ] Order navigation works
- [ ] Offline changes queued

---

## Handoff Notes

**For Stage 09:**
- Device lookup by QR will use this detail view
- Device ID from scan → DeviceDetailView
