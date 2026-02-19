# Stage 3: POS Card Payment + Payment Links

## Objective

Create `PosCardPaymentSheet.swift` — a full card payment flow with terminal selection, real-time polling, payment link fallback, and success/failure states. This is the most complex stage, matching the web app's `CardPaymentModal`.

## Dependencies

Stage 1 (Models, API Endpoints & PaymentService)

## Can Run In Parallel With

Stage 2 (Manual Payment), Stage 4 (Buyback Payout)

## Complexity

High

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Orders/PosCardPaymentSheet.swift` | Card payment via POS terminal with polling + payment link fallback |

## Implementation Details

### State Machine

The sheet uses a clear state machine to manage the payment lifecycle:

```swift
private enum PaymentState {
    case select              // Choose terminal, amount, devices
    case processing          // Sent to terminal, polling for card tap
    case success(cardBrand: String?, lastFour: String?)  // Payment completed
    case failed(reason: String?)   // Payment declined/errored
    case cancelled           // User or system cancelled
    case timeout             // 120s elapsed with no response
    case linkCreated(url: String, emailSent: Bool)  // Payment link generated
}

private enum PaymentMode {
    case terminal            // Pay via POS terminal
    case link                // Send payment link
}
```

### Layout by State

**`select` state:**
```
NavigationStack > ScrollView > VStack
├── Order Summary Card
│   ├── Order: #ORD-001
│   ├── Order Total: £150.00
│   ├── Already Paid: £50.00
│   └── Balance Due: £100.00 (large, bold)
├── Payment Mode Toggle (Terminal / Send Link)
├── [Terminal Mode] Terminal Picker
│   ├── Terminal cards (icon, name, provider label)
│   └── Selected = blue border + checkmark
├── [Link Mode] Customer Email field
├── Device Selection (checkboxes)
│   ├── Each device with: name, amount, status
│   ├── Incomplete repairs marked "Deposit only" (amber)
│   └── Ineligible devices disabled with "Not ready" tooltip
├── Amount Input
│   ├── Pre-filled with selected devices total
│   ├── Editable (cannot exceed selected total)
│   └── Warning if exceeds
├── Deposit Indicator (automatic, read-only)
│   └── "This will be recorded as a deposit" (amber, if any selected device incomplete)
└── Toolbar: Cancel + "Pay £X.XX on Terminal" / "Send Payment Link"
```

**`processing` state:**
```
VStack(centered)
├── ProgressView (spinning)
├── "Waiting for card..."
│   └── or "Processing payment..." (when status == .processing)
├── Timer countdown: "1:45 remaining"
├── Terminal name shown
└── "Cancel Payment" button (destructive)
```

**`success` state:**
```
VStack(centered)
├── Checkmark circle (green, large)
├── "Payment Successful!"
├── Amount: £100.00
├── Card info: "Visa ending in 4242" (if available)
└── "Done" button → dismisses sheet + refreshes order
```

**`failed` state:**
```
VStack(centered)
├── X circle (red, large)
├── "Payment Failed"
├── Reason text (from API failure_reason or default message)
├── "Try Again" button → resets to select state
└── "Close" button → dismisses
```

**`timeout` state:**
```
VStack(centered)
├── Clock icon (amber, large)
├── "Payment Timed Out"
├── "No response from terminal. Please check the terminal and try again."
├── "Try Again" button
└── "Close" button
```

**`linkCreated` state:**
```
VStack
├── Link icon (green)
├── "Payment Link Created"
├── Amount: £100.00
├── [If emailSent] "Email sent to customer@example.com"
├── Checkout URL (copyable)
│   └── "Copy Link" button with clipboard feedback
└── "Done" button
```

### Terminal Selection

```swift
@State private var selectedTerminalId: String?

// On appear: load from UserDefaults
private let lastTerminalKey = "pos_last_terminal_id"

// Filter to active terminals only
private var activeTerminals: [PosTerminal] {
    terminals.filter { $0.isActive == true }
}

// Auto-select if only 1 terminal
.onAppear {
    if activeTerminals.count == 1 {
        selectedTerminalId = activeTerminals[0].id
    } else if let last = UserDefaults.standard.string(forKey: lastTerminalKey),
              activeTerminals.contains(where: { $0.id == last }) {
        selectedTerminalId = last
    }
}
```

Terminal cards show provider branding:
- Revolut: purple gradient accent
- Square: blue gradient accent
- SumUp: teal gradient accent
- Dojo: orange gradient accent

### Device Selection

```swift
@State private var selectedDeviceIds: Set<String> = []

// Constants matching web app
private let repairCompleteStatuses: Set<String> = [
    "repaired_ready", "rejection_ready", "collected", "despatched"
]

private func canTakePayment(_ device: OrderDeviceSummary) -> Bool {
    if device.workflowType == "buyback" { return true }
    if repairCompleteStatuses.contains(device.status) { return true }
    return depositsEnabled
}

private func isDepositOnly(_ device: OrderDeviceSummary) -> Bool {
    if device.workflowType == "buyback" { return false }
    return !repairCompleteStatuses.contains(device.status)
}

// Auto-detect deposit flag
private var isDepositPayment: Bool {
    let selectedDevices = (order.devices ?? []).filter { selectedDeviceIds.contains($0.id) }
    return selectedDevices.contains { isDepositOnly($0) }
}
```

### Amount Calculation

```swift
// Amount in currency units (pounds)
@State private var customAmountText: String = ""

private var selectedDevicesTotal: Double {
    // Sum line totals for selected devices
    // This requires device breakdown data from the order
    guard let devices = order.devices else { return balanceDue }
    let selected = devices.filter { selectedDeviceIds.contains($0.id) }
    return selected.reduce(0) { sum, device in
        let deviceTotal = (device.deposits ?? 0) + (device.finalPaid ?? 0)
        let lineTotal = /* from order items linked to this device */ 0.0
        return sum + lineTotal - deviceTotal
    }
}

private var paymentAmountPounds: Double {
    if let custom = Double(customAmountText), custom > 0 {
        return custom
    }
    return selectedDeviceIds.isEmpty ? balanceDue : selectedDevicesTotal
}

// Convert to pence for POS API
private var paymentAmountPence: Int {
    Int(round(paymentAmountPounds * 100))
}
```

### Polling Logic

```swift
private let pollInterval: TimeInterval = 2.0
private let maxPollTime: TimeInterval = 120.0

@State private var timeRemaining: Int = 120  // seconds
@State private var pollTask: Task<Void, Never>?

private func startPolling(transactionId: String) {
    state = .processing
    timeRemaining = 120

    pollTask = Task {
        // Countdown timer
        let timerTask = Task {
            while !Task.isCancelled && timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                timeRemaining -= 1
            }
        }

        // Polling loop
        while !Task.isCancelled {
            do {
                let response = try await paymentService.pollPaymentStatus(transactionId: transactionId)

                if response.status.isTerminal {
                    timerTask.cancel()
                    handleTerminalStatus(response)
                    return
                }

                // Update processing sub-state
                if response.status == .processing {
                    // Could update UI to show "Processing..."
                }

                try await Task.sleep(for: .seconds(pollInterval))
            } catch {
                // Network error during poll — don't stop, retry
                try? await Task.sleep(for: .seconds(pollInterval))
            }

            // Check timeout
            if timeRemaining <= 0 {
                timerTask.cancel()
                state = .timeout
                return
            }
        }
    }
}

private func handleTerminalStatus(_ response: PosTransactionPollResponse) {
    switch response.status {
    case .completed:
        state = .success(cardBrand: response.cardBrand, lastFour: response.cardLastFour)
    case .failed:
        state = .failed(reason: response.failureReason)
    case .cancelled:
        state = .cancelled
    case .timeout:
        state = .timeout
    default:
        break
    }
}

private func stopPolling() {
    pollTask?.cancel()
    pollTask = nil
}
```

### App Lifecycle Handling

```swift
@Environment(\.scenePhase) private var scenePhase

.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active, case .processing = state {
        // App returned to foreground during polling
        // Polling task may have been suspended — it will resume automatically
        // with structured concurrency. Just update the timer display.
    }
}
```

### Initiate Payment

```swift
private func initiateTerminalPayment() async {
    guard let terminalId = selectedTerminalId else { return }

    // Save last-used terminal
    UserDefaults.standard.set(terminalId, forKey: lastTerminalKey)

    let request = InitiateTerminalPaymentRequest(
        orderId: order.id,
        terminalId: terminalId,
        amount: paymentAmountPence,
        currency: "GBP",
        deviceIds: selectedDeviceIds.isEmpty ? nil : Array(selectedDeviceIds),
        isDeposit: isDepositPayment ? true : nil
    )

    do {
        let response = try await paymentService.initiateTerminalPayment(request)
        startPolling(transactionId: response.transactionId)
    } catch let error as APIError {
        state = .failed(reason: error.localizedDescription)
    } catch {
        state = .failed(reason: error.localizedDescription)
    }
}
```

### Cancel Payment

```swift
private func cancelPayment() async {
    stopPolling()
    if let transactionId = currentTransactionId {
        try? await paymentService.cancelTerminalPayment(transactionId: transactionId)
    }
    state = .cancelled
}
```

### Payment Link Creation

```swift
private func createPaymentLink() async {
    let request = CreatePaymentLinkRequest(
        orderId: order.id,
        amount: paymentAmountPence,
        currency: "GBP",
        customerEmail: customerEmail.isEmpty ? nil : customerEmail,
        description: "Order #\(order.orderNumber ?? "")",
        deviceIds: selectedDeviceIds.isEmpty ? nil : Array(selectedDeviceIds),
        isDeposit: isDepositPayment ? true : nil
    )

    do {
        let response = try await paymentService.createPaymentLink(request)
        state = .linkCreated(url: response.checkoutUrl, emailSent: response.emailSent == true)
    } catch let error as APIError {
        state = .failed(reason: error.localizedDescription)
    } catch {
        state = .failed(reason: error.localizedDescription)
    }
}
```

### Props / Init

```swift
struct PosCardPaymentSheet: View {
    let order: Order
    let balanceDue: Double
    let depositsEnabled: Bool
    let terminals: [PosTerminal]
    let paymentService: PaymentService
    let onSuccess: () async -> Void  // Called to refresh order after payment

    @Environment(\.dismiss) private var dismiss
    @State private var state: PaymentState = .select
    @State private var paymentMode: PaymentMode = .terminal
    @State private var selectedTerminalId: String?
    @State private var selectedDeviceIds: Set<String> = []
    @State private var customAmountText: String = ""
    @State private var customerEmail: String = ""
    @State private var currentTransactionId: String?
    @State private var timeRemaining: Int = 120
    @State private var pollTask: Task<Void, Never>?
}
```

### Timer Display

```swift
private var formattedTimeRemaining: String {
    let mins = timeRemaining / 60
    let secs = timeRemaining % 60
    return String(format: "%d:%02d", mins, secs)
}
```

### Sheet Dismissal

```swift
.onDisappear {
    stopPolling()
}

// "Done" on success
private func handleDone() async {
    await onSuccess()
    dismiss()
}
```

## Test Cases

| Scenario | Input | Expected Output |
|----------|-------|-----------------|
| Single terminal | 1 active terminal | Auto-selected, no picker shown |
| Multiple terminals | 3 active terminals | Picker shown, last-used pre-selected |
| No terminals | `terminals` is empty | Terminal mode disabled, link mode default |
| Initiate payment | Valid terminal + amount | State → `.processing`, polling starts |
| Poll — pending | Status = "pending" | "Waiting for card..." with countdown |
| Poll — processing | Status = "processing" | "Processing payment..." |
| Poll — completed | Status = "completed" + card info | State → `.success`, card brand/last4 shown |
| Poll — failed | Status = "failed" + reason | State → `.failed`, reason shown |
| Poll — timeout | 120s elapsed | State → `.timeout`, "check terminal" message |
| Cancel during poll | Tap "Cancel Payment" | Polling stops, API cancel called, state → `.cancelled` |
| Create link — success | Valid email + amount | State → `.linkCreated`, URL shown |
| Create link — no email | Email empty | Link created, `emailSent: false` |
| Copy link URL | Tap "Copy Link" | URL copied to clipboard, "Copied!" feedback |
| Device selection | Select 2 of 3 devices | Amount updates to sum of selected |
| Deposit auto-detect | Select incomplete repair device | "This will be recorded as a deposit" shown |
| App backgrounded | Switch apps during polling | Polling resumes on foreground return |
| Try again | From failed state | Reset to `.select` |

## Acceptance Checklist

- [ ] `PosCardPaymentSheet.swift` created in `Features/Staff/Orders/`
- [ ] State machine with 7 states implemented
- [ ] Terminal picker with auto-select and last-used persistence
- [ ] Device selection with eligibility checks
- [ ] Amount input with validation (cannot exceed selected total)
- [ ] Deposit auto-detection based on device statuses
- [ ] Terminal payment initiation calls `POST /api/pos/payments`
- [ ] 2-second polling loop with 120-second timeout
- [ ] Countdown timer display during polling
- [ ] Cancel button stops polling and calls cancel API
- [ ] Success state shows card brand and last 4 digits
- [ ] Failed state shows reason with "Try Again" button
- [ ] Timeout state shows clear message
- [ ] Payment link mode with email input
- [ ] Link created state with copyable URL
- [ ] Polling cleanup on sheet dismissal
- [ ] App builds without warnings

## Deployment

No deployment — iOS code only. Cannot be fully tested until Stage 5 wires it into OrderDetailView, but the sheet should compile and preview should render the `select` state.

## Handoff Notes

Stage 5 needs:
- `PosCardPaymentSheet` view with its init parameters
- Understanding that `onSuccess` should call `viewModel.refresh()` and `viewModel.loadPaymentLinks()`
- Terminal and link modes are both contained within this single sheet
