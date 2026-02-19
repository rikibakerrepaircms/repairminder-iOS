# iOS Order Payments — Master Plan

## Feature Overview

Add full payment recording capabilities to the iOS app's order detail view, matching the web dashboard's functionality. This covers three distinct payment flows:

1. **Manual payments** — Cash, bank transfer, card (manual entry), PayPal, invoice, other
2. **POS terminal payments** — Card payments via Revolut (or other configured POS provider) with real-time polling
3. **Buyback payouts** — Paying suppliers/customers for buyback inventory devices

Currently the iOS `OrderDetailView` displays payments and totals read-only. The backend API endpoints for all three flows already exist and are production-ready.

## Success Criteria

- Staff can record a manual payment (cash, bank transfer, invoice, PayPal, other) with amount, method, date, notes, and optional device link
- Staff can initiate a card payment on a POS terminal, see real-time polling status, and receive success/failure confirmation
- Staff can create a payment link (checkout URL) as a fallback when terminals are unavailable or for remote customers
- Payment links are displayed on the order detail with status, copy URL, and cancel actions
- Staff can record a buyback payout (cash or bank transfer) for devices in `readyToPay` status
- Deposit toggle shown when company has `depositsEnabled == 1` — allows payment on incomplete repair devices
- Device-scoped payments supported (link payment to specific device)
- Totals section updates after every payment action (via order refresh)
- Delete payment supported with confirmation prompt
- All payment UI hidden on collected/despatched orders (matches `isOrderEditable`)
- Terminal selection filters by user's current location (matching web app)
- iPad layout works correctly within `AnimatedSplitView` detail pane

## Dependencies & Prerequisites

- All payment API endpoints already exist (manual, POS, payment links)
- `APIEndpoints.swift` already has `createOrderPayment`, `deleteOrderPayment` cases
- `OrderPayment` model already decodes all 18 fields including POS and refund data
- `PaymentMethod` enum already has all 6 cases with labels and icons
- `PaymentStatus` enum already has 4 cases with colours
- `OrderTotals` already has `balanceDue`, `depositsPaid`, `amountPaid`, etc.
- `OrderCompany` already has `depositsEnabled` field
- `OrderDetailViewModel` already has `isOrderEditable` computed property
- `OrderItemFormSheet` pattern exists for form sheet presentation
- `FormTextField` reusable component exists
- `SectionCard` component exists

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| App backgrounded during POS polling | Medium | Medium | Resume polling on `scenePhase` change; show "checking status" on return |
| Terminal not responding (stuck in pending) | Medium | Low | 120s timeout with clear "timed out" message; cancel button always available |
| Amount precision (floating point) | Low | Medium | Use `Decimal` for all currency calculations; API uses pence (integers) |
| Multiple terminals at location | Low | Low | Terminal picker with last-used persistence via `UserDefaults` |
| Payment link email not delivered | Low | Low | Always show copyable checkout URL as fallback |
| Overpayment race condition | Low | Medium | Backend validates; iOS shows server error if amount exceeds balance |

## Stage Index

| Stage | Name | Depends On | Parallel With |
|-------|------|-----------|---------------|
| 1 | [Models, API Endpoints & PaymentService](01-models-api-service.md) | — | — |
| 2 | [Manual Payment Sheet](02-manual-payment-sheet.md) | 1 | 3, 4 |
| 3 | [POS Card Payment + Payment Links](03-pos-card-payment.md) | 1 | 2, 4 |
| 4 | [Buyback Payout Sheet](04-buyback-payout-sheet.md) | 1 | 2, 3 |
| 5 | [OrderDetailView Integration](05-order-detail-integration.md) | 2, 3, 4 | — |

**Parallelism:** After Stage 1 completes, Stages 2, 3, and 4 can all be implemented concurrently — they share the same foundation but produce independent UI components. Stage 5 wires everything together.

## Architecture Overview

```
OrderDetailView
├── "Add Payment" button → OrderPaymentFormSheet (Stage 2)
├── "Take Card Payment" button → PosCardPaymentSheet (Stage 3)
│   └── Payment Link fallback mode (Stage 3)
├── "Record Payout" button → BuybackPayoutSheet (Stage 4)
├── Payment Links section (Stage 5)
└── Payments section (existing, enhanced in Stage 5)

PaymentService (Stage 1)
├── recordManualPayment()
├── deletePayment()
├── fetchPosIntegrations()
├── fetchPosTerminals(locationId:)
├── initiateTerminalPayment()
├── pollPaymentStatus()
├── cancelTerminalPayment()
├── createPaymentLink()
├── fetchPaymentLinks(orderId:)
├── cancelPaymentLink()
└── resendPaymentLinkEmail()
```

## API Endpoints Summary

### Already Defined in APIEndpoints.swift
| Endpoint | iOS Case |
|----------|----------|
| `GET /api/orders/:id/payments` | `orderPayments(orderId:)` |
| `POST /api/orders/:id/payments` | `createOrderPayment(orderId:)` |
| `DELETE /api/orders/:id/payments/:paymentId` | `deleteOrderPayment(orderId:, paymentId:)` |

### New Endpoints Needed
| Endpoint | Purpose |
|----------|---------|
| `GET /api/pos/integrations` | Check if company has POS configured |
| `GET /api/pos/terminals?location_id=X` | List terminals at user's location |
| `POST /api/pos/payments` | Initiate card payment on terminal |
| `GET /api/pos/payments/:id/status` | Poll payment status (2s interval) |
| `POST /api/pos/payments/:id/cancel` | Cancel pending terminal payment |
| `POST /api/pos/payment-links` | Create checkout link |
| `GET /api/pos/payment-links?order_id=X` | List payment links for order |
| `POST /api/pos/payment-links/:id/cancel` | Cancel payment link |
| `POST /api/pos/payment-links/:id/resend` | Resend link email |

## Key Business Rules

### Payment Amount
- Manual payments: amount in **currency units** (pounds), API accepts `amount: 99.99`
- POS payments: amount in **pence/cents** (minor units), API accepts `amount: 9999`
- Amount cannot exceed device/order balance + £0.01 tolerance (backend validates)

### Device Eligibility for Payment
- **Repair devices**: Must be in `repairedReady`, `rejectionReady`, `collected`, or `despatched` status
- **Exception**: Deposit payments allowed on ANY status if `depositsEnabled == 1`
- **Buyback devices**: Only `readyToPay` status allows payout
- **Payout completion**: Device auto-transitions to `paymentMade` after payout recorded

### Deposit Logic
- `depositsEnabled` checked from `order.company?.depositsEnabled == 1`
- Deposit flag is automatic in POS flow: if ANY selected device has incomplete status → `is_deposit: true`
- Manual flow: explicit toggle shown when deposits enabled

### Payment Links
- Created as fallback to terminal payment
- Sent to customer email AND posted as ticket message
- Auto-cancelled when any payment (manual or terminal) is recorded
- Displayed in order detail with pending/completed/cancelled status
- Copyable checkout URL always visible for pending links

## Out of Scope

- **Refund recording** — Deferred (web app has RefundModal, iOS v1 will not support)
- **Pre/post-payment signature capture** — Web has PrePaymentCollectionModal / PostPaymentCollectionModal; deferred
- **Cash drawer integration** — Web triggers cash drawer via Print Bridge; not applicable to iOS
- **Square POS integration** — Backend supports it, but Revolut is the active provider; no Square-specific UI needed
- **Offline payment queueing** — All payments require network connectivity
- **Payment receipts / printing** — Deferred
