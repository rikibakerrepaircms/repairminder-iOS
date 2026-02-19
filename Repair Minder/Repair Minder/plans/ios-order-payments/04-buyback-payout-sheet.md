# Stage 4: Buyback Payout Sheet

## Objective

Create `BuybackPayoutSheet.swift` — a form sheet for recording payments TO customers/suppliers for buyback inventory devices. This matches the web app's `MakePaymentModal` component, which is separate from the standard payment flow.

## Dependencies

Stage 1 (Models, API Endpoints & PaymentService)

## Can Run In Parallel With

Stage 2 (Manual Payment), Stage 3 (POS Card Payment)

## Complexity

Medium

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Orders/BuybackPayoutSheet.swift` | Buyback payout recording for cash or bank transfer |

## Implementation Details

### Context

When a company buys devices from customers (buyback/trade-in), the device goes through diagnosis and grading. Once the device reaches `readyToPay` status, staff must record the payout. The payout amount was agreed during authorization.

### Layout

```
NavigationStack > ScrollView > VStack(spacing: 20)
├── Device Info Card
│   ├── Device name (e.g. "iPhone 15 Pro Max 256GB")
│   ├── Serial / IMEI
│   ├── Payout amount (large, green): £120.00
│   └── Status badge: "Ready to Pay"
├── Payment Method Picker
│   ├── "Bank Transfer" card (with building.columns icon)
│   └── "Cash" card (with banknote icon)
├── [Bank Transfer] Bank Details Display
│   ├── Account Holder: John Smith [Copy]
│   ├── Sort Code: 12-34-56 [Copy]
│   ├── Account Number: 12345678 [Copy]
│   └── Payment Reference field (required)
├── [Cash] Notes field (optional)
│   └── Placeholder: "e.g. Paid in cash at counter"
└── Toolbar: Cancel + "Record Payout" (disabled until valid)
```

### Payment Method Picker

Only two options for buyback payouts (matching web app):

```swift
private enum PayoutMethod: String, CaseIterable, Identifiable {
    case bankTransfer = "bank_transfer"
    case cash

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bankTransfer: return "Bank Transfer"
        case .cash: return "Cash"
        }
    }

    var icon: String {
        switch self {
        case .bankTransfer: return "building.columns"
        case .cash: return "banknote"
        }
    }
}
```

### Bank Details

Bank details come from the device's authorization data. The web app parses these from `authorization_notes` JSON on the order device. The iOS model should have these available from the order detail response.

```swift
// Bank details parsed from device authorization
struct BankDetails {
    let accountHolder: String?
    let sortCode: String?
    let accountNumber: String?
}
```

Each field has a "Copy" button:
```swift
private func copyableField(label: String, value: String) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        Spacer()
        Button {
            UIPasteboard.general.string = value
            copiedField = label
            // Reset after 2s
            Task {
                try? await Task.sleep(for: .seconds(2))
                if copiedField == label { copiedField = nil }
            }
        } label: {
            Image(systemName: copiedField == label ? "checkmark" : "doc.on.doc")
                .font(.caption)
                .foregroundStyle(copiedField == label ? .green : .blue)
        }
    }
    .padding(12)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

### Payment Reference (Bank Transfer)

Required field when bank transfer is selected:
```swift
FormTextField(
    label: "Payment Reference",
    text: $paymentReference,
    placeholder: "e.g. Bank transaction ID"
)
```

### Form Validation

```swift
private var isFormValid: Bool {
    guard selectedMethod != nil else { return false }
    if selectedMethod == .bankTransfer {
        return !paymentReference.trimmingCharacters(in: .whitespaces).isEmpty
    }
    return true  // Cash has no required fields
}
```

### Save Action

The payout is sent as a regular payment with `is_payout: true` — the backend negates the amount and transitions the device status.

```swift
private func handleSave() async {
    guard let method = selectedMethod else { return }
    isSaving = true

    var notes = ""
    if method == .bankTransfer {
        notes = "Ref: \(paymentReference)"
        if !additionalNotes.trimmingCharacters(in: .whitespaces).isEmpty {
            notes += " - \(additionalNotes)"
        }
    } else {
        notes = cashNotes.trimmingCharacters(in: .whitespaces)
    }

    let request = ManualPaymentRequest(
        amount: payoutAmount,
        paymentMethod: method.rawValue,
        paymentDate: DateFormatters.isoDate(from: Date()),
        notes: notes.isEmpty ? nil : notes,
        deviceId: device.id,
        isDeposit: nil,
        isPayout: true
    )

    let success = await onSave(request)
    isSaving = false
    if success {
        dismiss()
    }
}
```

### Props / Init

```swift
struct BuybackPayoutSheet: View {
    let device: OrderDeviceSummary
    let payoutAmount: Double
    let bankDetails: BankDetails?
    let orderNumber: String
    let onSave: (ManualPaymentRequest) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: PayoutMethod? = .bankTransfer  // Default to bank transfer
    @State private var paymentReference: String = ""
    @State private var cashNotes: String = ""
    @State private var additionalNotes: String = ""
    @State private var isSaving: Bool = false
    @State private var copiedField: String? = nil
}
```

### Device Info Display

```swift
private var deviceInfoCard: some View {
    SectionCard(title: "Device", icon: "iphone") {
        VStack(alignment: .leading, spacing: 8) {
            Text(device.displayName ?? "Unknown Device")
                .font(.headline)

            if let serial = device.serialNumber {
                Label(serial, systemImage: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Payout Amount")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(CurrencyFormatter.format(payoutAmount))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }
        }
    }
}
```

## Test Cases

| Scenario | Input | Expected Output |
|----------|-------|-----------------|
| Default method | Sheet opens | Bank Transfer pre-selected |
| Bank details shown | Device has bank info | Account holder, sort code, account number displayed |
| No bank details | Device has no bank info | "No bank details available" message, Cash auto-selected |
| Copy account holder | Tap copy button | Copied to clipboard, checkmark shown briefly |
| Payment reference required | Bank transfer, empty ref | "Record Payout" disabled |
| Payment reference filled | "TXN-12345" entered | "Record Payout" enabled |
| Cash method | Select Cash | No bank details shown, optional notes field |
| Save payout | Valid form | `is_payout: true` in request, sheet dismisses |
| Save failure | API error | Sheet stays open, error shown |

## Acceptance Checklist

- [ ] `BuybackPayoutSheet.swift` created in `Features/Staff/Orders/`
- [ ] Device info card shows name, serial/IMEI, payout amount
- [ ] Payment method picker with Bank Transfer and Cash options
- [ ] Bank details displayed with individual copy buttons
- [ ] Payment reference required for bank transfers
- [ ] Cash flow has optional notes only
- [ ] `is_payout: true` sent in `ManualPaymentRequest`
- [ ] `device_id` always included in request
- [ ] Form validation prevents invalid submissions
- [ ] Sheet dismisses on success
- [ ] App builds without warnings

## Deployment

No deployment — iOS code only. Cannot be fully tested until Stage 5 wires it into OrderDetailView.

## Handoff Notes

Stage 5 needs:
- `BuybackPayoutSheet` view with its init parameters
- This sheet is shown for buyback workflow devices in `readyToPay` status
- The `onSave` closure calls `viewModel.recordPayment(request)` — same as manual payments
- After success, the device status transitions to `paymentMade` (server-side)
