# Stage 5: OrderDetailView Integration

## Objective

Wire all payment sheets (Stages 2, 3, 4) into `OrderDetailView.swift`, add payment action buttons with correct visibility logic, enhance the payments display section, add payment links display, and add delete payment support. This is the final integration stage.

## Dependencies

Stage 2 (Manual Payment Sheet), Stage 3 (POS Card Payment), Stage 4 (Buyback Payout Sheet)

## Complexity

Medium

## Files to Modify

| File | Changes |
|------|---------|
| `Features/Staff/Orders/OrderDetailView.swift` | Add payment buttons, payment links section, delete payment, wire sheets |
| `Features/Staff/Orders/OrderDetailViewModel.swift` | Add `loadPosConfig` call to `loadOrder()`, minor state additions |

## Implementation Details

### 1. New State in OrderDetailView

```swift
// Payment sheets
@State private var showPaymentSheet = false
@State private var showCardPaymentSheet = false
@State private var showPayoutSheet = false
@State private var payoutDevice: OrderDeviceSummary? = nil

// Delete payment
@State private var deletingPaymentId: String? = nil
@State private var showDeletePaymentAlert = false
```

### 2. Payment Buttons Section

Add a new section between the totals section and existing payments section. This section contains the action buttons for recording payments.

**Visibility conditions (matching web app):**

```swift
@ViewBuilder
private func paymentActionsSection() -> some View {
    if viewModel.isOrderEditable, let order = viewModel.order,
       (order.totals?.balanceDue ?? order.balanceDue ?? 0) > 0 {

        VStack(spacing: 8) {
            // "Take Card Payment" button — only if POS terminals available
            if viewModel.hasActiveTerminals {
                Button {
                    showCardPaymentSheet = true
                } label: {
                    Label("Take Card Payment", systemImage: "creditcard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
            }

            // "Add Payment" button — always shown
            Button {
                showPaymentSheet = true
            } label: {
                Label("Add Payment", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            // "Record Payout" button — for buyback devices in readyToPay status
            if let payableDevice = buybackDeviceReadyToPay {
                Button {
                    payoutDevice = payableDevice
                    showPayoutSheet = true
                } label: {
                    Label("Record Payout", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        }
        .padding(.horizontal)
    }
}

private var buybackDeviceReadyToPay: OrderDeviceSummary? {
    viewModel.order?.devices?.first {
        $0.workflowType == "buyback" && $0.status == "ready_to_pay"
    }
}
```

### 3. Enhanced Payments Section

Update the existing `paymentsSection` to add:
- Swipe-to-delete on each payment row
- POS card info display (card brand + last 4) for terminal payments
- Refund indicator for refunded payments

```swift
private func paymentsSection(_ payments: [OrderPayment]) -> some View {
    SectionCard(title: "Payments", icon: "creditcard") {
        VStack(spacing: 8) {
            ForEach(payments) { payment in
                paymentRow(payment)

                if payment.id != payments.last?.id {
                    Divider()
                }
            }
        }
    }
}

private func paymentRow(_ payment: OrderPayment) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let method = payment.paymentMethod {
                    Image(systemName: method.icon)
                        .font(.caption)
                }
                Text(payment.paymentMethod?.label ?? "Payment")
                    .font(.subheadline)

                if payment.isDepositPayment {
                    Text("Deposit")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            // Card info for POS payments
            if let brand = payment.cardBrand, let last4 = payment.cardLastFour {
                Text("\(brand.capitalized) ending in \(last4)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let date = payment.formattedDate {
                Text(date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let notes = payment.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
            Text(payment.formattedAmount)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(payment.amount < 0 ? .red : .green)

            // Refund info
            if let refunded = payment.totalRefunded, refunded > 0 {
                Text("Refunded: \(CurrencyFormatter.format(refunded))")
                    .font(.caption2)
                    .foregroundStyle(.purple)
            }
        }
    }
    .padding(.vertical, 4)
    .contextMenu {
        if viewModel.isOrderEditable && payment.posTransactionId == nil {
            // Only allow deleting non-POS payments
            Button(role: .destructive) {
                deletingPaymentId = payment.id
                showDeletePaymentAlert = true
            } label: {
                Label("Delete Payment", systemImage: "trash")
            }
        }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        if viewModel.isOrderEditable && payment.posTransactionId == nil {
            Button(role: .destructive) {
                deletingPaymentId = payment.id
                showDeletePaymentAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
```

### 4. Payment Links Section

Add a new section to display active payment links:

```swift
@ViewBuilder
private func paymentLinksSection() -> some View {
    let links = viewModel.paymentLinks
    if !links.isEmpty {
        SectionCard(title: "Payment Links", icon: "link") {
            VStack(spacing: 8) {
                ForEach(links) { link in
                    paymentLinkRow(link)

                    if link.id != links.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private func paymentLinkRow(_ link: PosPaymentLink) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack {
            Text(link.formattedAmount)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            // Status badge
            Text(link.status.rawValue.capitalized)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(paymentLinkStatusColor(link.status).opacity(0.1))
                .foregroundStyle(paymentLinkStatusColor(link.status))
                .clipShape(Capsule())
        }

        // Date info
        if let date = link.formattedCreatedAt {
            Text(link.status == .pending ? "Sent \(date)" :
                 link.status == .completed ? "Paid \(date)" :
                 "Cancelled \(date)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        // Actions for pending links
        if link.status == .pending {
            HStack(spacing: 12) {
                // Copy URL
                Button {
                    UIPasteboard.general.string = link.checkoutUrl
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Cancel
                Button(role: .destructive) {
                    Task {
                        await viewModel.cancelPaymentLink(linkId: link.id)
                    }
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    .padding(.vertical, 4)
}

private func paymentLinkStatusColor(_ status: PaymentLinkStatus) -> Color {
    switch status {
    case .pending: return .orange
    case .completed: return .green
    case .failed: return .red
    case .cancelled: return .gray
    case .expired: return .gray
    }
}
```

### 5. Sheet Presentation

Add to the `body` view modifiers:

```swift
// Manual payment sheet
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

// Card payment sheet
.sheet(isPresented: $showCardPaymentSheet) {
    if let order = viewModel.order {
        PosCardPaymentSheet(
            order: order,
            balanceDue: viewModel.balanceDue,
            depositsEnabled: viewModel.depositsEnabled,
            terminals: viewModel.posTerminals,
            paymentService: PaymentService()
        ) {
            await viewModel.refresh()
            await viewModel.loadPaymentLinks()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// Buyback payout sheet
.sheet(isPresented: $showPayoutSheet) {
    if let order = viewModel.order, let device = payoutDevice {
        BuybackPayoutSheet(
            device: device,
            payoutAmount: device.payoutAmount ?? 0,
            bankDetails: nil,  // TODO: Parse from authorization data
            orderNumber: order.orderNumber
        ) { request in
            await viewModel.recordPayment(request)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// Delete payment alert
.alert("Delete Payment", isPresented: $showDeletePaymentAlert) {
    Button("Cancel", role: .cancel) {
        deletingPaymentId = nil
    }
    Button("Delete", role: .destructive) {
        if let paymentId = deletingPaymentId {
            Task {
                _ = await viewModel.deletePayment(paymentId: paymentId)
                deletingPaymentId = nil
            }
        }
    }
} message: {
    Text("Are you sure you want to delete this payment? This cannot be undone.")
}
```

### 6. Section Ordering in ScrollView

Update the order of sections in the main `ScrollView` `VStack`:

```swift
// ... existing sections (header, client, devices, items, totals) ...

paymentActionsSection()      // NEW: buttons
paymentLinksSection()         // NEW: active links

if let payments = order.payments, !payments.isEmpty {
    paymentsSection(payments) // ENHANCED: swipe-to-delete + card info
}

// ... remaining sections (refunds, signatures, timeline, notes) ...
```

### 7. Load POS Config on Order Load

In `OrderDetailViewModel.loadOrder()`, after successful order fetch, add:

```swift
// After order is set:
Task {
    async let posConfig: Void = loadPosConfig(locationId: currentLocationId)
    async let links: Void = loadPaymentLinks()
    _ = await (posConfig, links)
}
```

The `currentLocationId` should come from the app's auth/session context — check how other parts of the app access the user's current location.

### 8. Payment Error Alert

Add an alert for payment errors:

```swift
.alert("Payment Error", isPresented: .init(
    get: { viewModel.paymentError != nil },
    set: { if !$0 { viewModel.clearPaymentError() } }
)) {
    Button("OK") { viewModel.clearPaymentError() }
} message: {
    Text(viewModel.paymentError ?? "")
}
```

## Test Cases

| Scenario | Input | Expected Output |
|----------|-------|-----------------|
| Balance > 0, no POS | Unpaid order, no integrations | Only "Add Payment" button visible |
| Balance > 0, with POS | Unpaid order, terminals available | Both "Take Card Payment" and "Add Payment" visible |
| Balance == 0 | Fully paid order | No payment buttons shown |
| Collected order | `status == collectedDespatched` | No payment buttons shown |
| Buyback ready to pay | Device in `readyToPay` | "Record Payout" button visible |
| Open manual sheet | Tap "Add Payment" | `OrderPaymentFormSheet` presented |
| Open card sheet | Tap "Take Card Payment" | `PosCardPaymentSheet` presented |
| Open payout sheet | Tap "Record Payout" | `BuybackPayoutSheet` presented |
| Delete manual payment | Swipe left on cash payment | Delete confirmation alert shown |
| Delete POS payment | Try swipe on card payment | Swipe action not available |
| Confirm delete | Tap "Delete" in alert | Payment removed, order refreshed |
| Payment links shown | Order has pending link | Link row with amount, status, copy/cancel buttons |
| Cancel payment link | Tap "Cancel" on link | Link status → cancelled, refreshed |
| Copy link URL | Tap "Copy Link" | URL in clipboard |
| After payment success | Any sheet completes | Order refreshed, new payment in list, balance updated |

## Acceptance Checklist

- [ ] "Take Card Payment" button shown only when POS terminals available AND balance > 0
- [ ] "Add Payment" button always shown when balance > 0 and order editable
- [ ] "Record Payout" button shown for buyback devices in `readyToPay` status
- [ ] All three sheets correctly presented with `.presentationDetents`
- [ ] Manual payment sheet receives correct props and refreshes order on success
- [ ] Card payment sheet receives terminals and refreshes on success
- [ ] Buyback payout sheet receives device info and refreshes on success
- [ ] Payments section shows card brand/last4 for POS payments
- [ ] Payments section shows notes (1-line truncated)
- [ ] Swipe-to-delete on non-POS payments only
- [ ] Delete confirmation alert with destructive action
- [ ] Payment links section displays with status badges and colours
- [ ] Pending links have "Copy Link" and "Cancel" actions
- [ ] POS config loaded during order load (non-blocking)
- [ ] Payment links loaded during order load (non-blocking)
- [ ] Payment error alert shown and clearable
- [ ] No buttons visible on collected/despatched orders
- [ ] iPad layout works within `AnimatedSplitView` detail pane
- [ ] App builds without warnings

## Deployment

No deployment — iOS code only. Build and run on simulator/device:

1. Open an unpaid order → verify "Add Payment" button appears
2. If company has POS → verify "Take Card Payment" appears
3. Record a cash payment → verify it appears in payments list
4. Verify totals update after payment
5. Delete the payment → verify it's removed
6. If buyback order → verify "Record Payout" button appears
7. Test on iPad split view → verify layout is correct

## Handoff Notes

This is the final stage. After completion:
- All three payment flows are functional
- Payment links are viewable and manageable
- The order detail page matches the web app's payment UX
- Future enhancements (refunds, signatures) can be layered on top
