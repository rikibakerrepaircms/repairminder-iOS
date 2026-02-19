# Stage 2: Manual Payment Sheet

## Objective

Create `OrderPaymentFormSheet.swift` — a form sheet for recording manual payments (cash, bank transfer, card manual entry, PayPal, invoice, other). This matches the web app's "Add Payment" modal on the order detail page.

## Dependencies

Stage 1 (Models, API Endpoints & PaymentService)

## Can Run In Parallel With

Stage 3 (POS Card Payment), Stage 4 (Buyback Payout)

## Complexity

Medium

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Orders/OrderPaymentFormSheet.swift` | Manual payment recording form sheet |

## Files to Modify

None in this stage — wiring into `OrderDetailView` happens in Stage 5.

## Implementation Details

### Form Layout

```
NavigationStack
├── ScrollView > VStack(spacing: 20)
│   ├── Payment Method Picker (grid of selectable cards)
│   ├── Amount Section
│   │   ├── Amount text field (decimal, pre-filled with balance due)
│   │   └── "Remaining balance: £X.XX" helper text
│   ├── Payment Date (DatePicker, defaults to today)
│   ├── Device Picker (optional, shown when deposits enabled or multiple devices)
│   │   ├── "Entire Order" option (default)
│   │   └── Individual device options with status indicators
│   ├── Deposit Toggle (only when depositsEnabled && device is incomplete repair)
│   │   └── Help text: "Payment taken before repair is complete"
│   ├── Notes field (optional, multi-line)
│   │   └── If method == .invoice: "Invoice Number" required field above notes
│   └── Totals Preview
│       ├── Order Total: £X.XX
│       ├── Already Paid: £X.XX
│       ├── This Payment: £X.XX
│       └── New Balance: £X.XX (green if £0.00)
└── Toolbar: Cancel (leading) + "Record Payment" (trailing, disabled until valid)
```

### Payment Method Picker

Use a `LazyVGrid` with 3 columns of selectable cards (matching web app's radio-style picker):

```swift
private enum ManualPaymentMethod: String, CaseIterable, Identifiable {
    case cash
    case card
    case bankTransfer = "bank_transfer"
    case paypal
    case invoice
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cash: return "Cash"
        case .card: return "Card"
        case .bankTransfer: return "Bank Transfer"
        case .paypal: return "PayPal"
        case .invoice: return "Invoice"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .bankTransfer: return "building.columns"
        case .paypal: return "p.circle"
        case .invoice: return "doc.text"
        case .other: return "ellipsis.circle"
        }
    }
}
```

Each card shows icon + label. Selected card has a blue border + checkmark.

### Amount Input

```swift
@State private var amountText: String  // Pre-filled with balanceDue formatted

// Validation:
private var parsedAmount: Double? {
    Double(amountText.replacingOccurrences(of: "£", with: "").trimmingCharacters(in: .whitespaces))
}

private var isAmountValid: Bool {
    guard let amount = parsedAmount else { return false }
    return amount > 0
}
```

Show helper text below: `"Balance due: \(CurrencyFormatter.format(balanceDue))"`

If entered amount > balance due, show amber warning: `"This exceeds the outstanding balance"` (not blocking — web app allows overpayment with server-side validation).

### Device Picker

Only shown when the order has devices (check `order.devices?.isEmpty == false`):

```swift
@State private var selectedDeviceId: String? = nil  // nil = entire order

// Device options:
// - "Entire Order" (always first, default)
// - Each device from order.devices with:
//   - display_name
//   - status badge
//   - individual balance (if available from device breakdown)
```

### Deposit Toggle

Visibility conditions:
1. `depositsEnabled == true` (from order.company)
2. Selected device is a repair device (not buyback)
3. Selected device is NOT in a complete status (`repairedReady`, `rejectionReady`, `collected`, `despatched`)

If all conditions met, show:
```swift
Toggle("Mark as Deposit", isOn: $isDeposit)
    .tint(.orange)
Text("Payment taken before repair is complete")
    .font(.caption)
    .foregroundStyle(.secondary)
```

### Invoice Number Field

Only shown when `selectedMethod == .invoice`:

```swift
if selectedMethod == .invoice {
    FormTextField(
        label: "Invoice Number",
        text: $invoiceNumber,
        placeholder: "e.g. INV-2024-001"
    )
}
```

The invoice number is prepended to notes when sending to API: `"Invoice #\(invoiceNumber) - \(notes)"` (matching web app behaviour).

### Notes Field

```swift
TextField("Notes (optional)", text: $notes, axis: .vertical)
    .lineLimit(3...6)
```

Placeholder varies by method:
- Cash: "e.g. Paid in cash at counter"
- Bank Transfer: "e.g. Transaction reference"
- Invoice: "Additional notes"
- Other: "Payment details"

### Form Validation

```swift
private var isFormValid: Bool {
    guard let amount = parsedAmount, amount > 0 else { return false }
    guard selectedMethod != nil else { return false }
    if selectedMethod == .invoice && invoiceNumber.trimmingCharacters(in: .whitespaces).isEmpty {
        return false
    }
    return true
}
```

### Save Action

```swift
private func handleSave() async {
    guard let method = selectedMethod, let amount = parsedAmount else { return }

    // Build notes string
    var finalNotes = notes.trimmingCharacters(in: .whitespaces)
    if method == .invoice && !invoiceNumber.isEmpty {
        finalNotes = "Invoice #\(invoiceNumber)" + (finalNotes.isEmpty ? "" : " - \(finalNotes)")
    }

    let request = ManualPaymentRequest(
        amount: amount,
        paymentMethod: method.rawValue,
        paymentDate: DateFormatters.isoDate(from: paymentDate),  // "YYYY-MM-DD"
        notes: finalNotes.isEmpty ? nil : finalNotes,
        deviceId: selectedDeviceId,
        isDeposit: isDeposit ? true : nil,
        isPayout: nil  // Not a payout in this sheet
    )

    let success = await onSave(request)
    if success {
        dismiss()
    }
}
```

### Props / Init

```swift
struct OrderPaymentFormSheet: View {
    let order: Order
    let balanceDue: Double
    let depositsEnabled: Bool
    let onSave: (ManualPaymentRequest) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: ManualPaymentMethod? = nil
    @State private var amountText: String = ""
    @State private var paymentDate: Date = .now
    @State private var notes: String = ""
    @State private var invoiceNumber: String = ""
    @State private var selectedDeviceId: String? = nil
    @State private var isDeposit: Bool = false
    @State private var isSaving: Bool = false

    init(order: Order, balanceDue: Double, depositsEnabled: Bool, onSave: @escaping (ManualPaymentRequest) async -> Bool) {
        self.order = order
        self.balanceDue = balanceDue
        self.depositsEnabled = depositsEnabled
        self.onSave = onSave
        // Pre-fill amount with balance due
        _amountText = State(initialValue: balanceDue > 0 ? String(format: "%.2f", balanceDue) : "")
    }
}
```

### Presentation (for Stage 5 reference)

```swift
.sheet(isPresented: $showPaymentSheet) {
    if let order = viewModel.order {
        OrderPaymentFormSheet(
            order: order,
            balanceDue: viewModel.balanceDue,
            depositsEnabled: viewModel.depositsEnabled
        ) { request in
            await viewModel.recordPayment(request)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
```

## Test Cases

| Scenario | Input | Expected Output |
|----------|-------|-----------------|
| Select cash method | Tap "Cash" card | Blue border + checkmark on Cash |
| Pre-filled amount | Balance due = £150.00 | Amount field shows "150.00" |
| Custom amount | Enter "75.50" | Parsed correctly, totals preview updates |
| Invalid amount | Enter "abc" | "Record Payment" button disabled |
| Invoice number required | Select "Invoice", leave number blank | Button disabled |
| Invoice number provided | Select "Invoice", enter "INV-001" | Button enabled |
| Deposit toggle — hidden | `depositsEnabled == false` | Toggle not visible |
| Deposit toggle — shown | `depositsEnabled == true`, incomplete repair device selected | Toggle visible |
| Notes with invoice | Invoice #INV-001, notes "Paid via BACS" | API receives "Invoice #INV-001 - Paid via BACS" |
| Save success | Valid form, API returns true | Sheet dismisses |
| Save failure | API returns error | Sheet stays open, error shown |
| Totals preview | Amount = 75.50, already paid = 50 | "New Balance: £24.50" |

## Acceptance Checklist

- [ ] `OrderPaymentFormSheet.swift` created in `Features/Staff/Orders/`
- [ ] 6 payment methods shown in grid picker with icons
- [ ] Amount pre-filled with balance due, editable
- [ ] Payment date defaults to today via DatePicker
- [ ] Device picker shows "Entire Order" + individual devices
- [ ] Deposit toggle shown only when conditions met
- [ ] Invoice number field shown only for invoice method
- [ ] Notes field with method-appropriate placeholder
- [ ] Totals preview section shows impact of payment
- [ ] Form validation prevents invalid submissions
- [ ] "Record Payment" button calls `onSave` closure
- [ ] Sheet dismisses on success, stays open on failure
- [ ] App builds without warnings

## Deployment

No deployment — iOS code only. Build and run on simulator. The sheet cannot be tested standalone until Stage 5 wires it into `OrderDetailView`, but the file should compile and the preview should render.

## Handoff Notes

Stage 5 needs:
- `OrderPaymentFormSheet` view with its `(order:, balanceDue:, depositsEnabled:, onSave:)` init
- Understanding that `onSave` calls `viewModel.recordPayment(request)` which refreshes the order
