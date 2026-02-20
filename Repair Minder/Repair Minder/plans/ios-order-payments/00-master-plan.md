# iOS Order Payments — Master Plan

## Overview

Add full payment management to the iOS staff app's order detail screen, matching the web app's payment UX. This includes manual payment recording, POS terminal card payments, payment link generation, buyback payouts, and payment deletion.

## Scope

- **iOS + minor backend fix** — all API endpoints exist, but POS handlers need response envelope fixes (see Backend Prerequisites).
- **Staff app only** — customer portal is out of scope.
- **5 stages** — sequential foundation (Stage 1), three parallel UI stages (2-4), and final integration (Stage 5).

## Architecture

```
Core/Models/PosModels.swift          ← NEW: POS terminals, transactions, payment links
Core/Models/Order.swift              ← MODIFY: add ManualPaymentRequest, extend OrderDeviceSummary
Core/Networking/APIEndpoints.swift   ← MODIFY: add 10 POS endpoint cases
Core/Services/PaymentService.swift   ← NEW: 11 methods wrapping POS + payment APIs
Features/Staff/Orders/
  OrderDetailViewModel.swift         ← MODIFY: payment state, POS config, 5 new methods + 4 computed properties
  OrderPaymentFormSheet.swift        ← NEW: Stage 2 — manual payment form
  PosCardPaymentSheet.swift          ← NEW: Stage 3 — terminal payment + payment links
  BuybackPayoutSheet.swift           ← NEW: Stage 4 — buyback payout recording
  OrderDetailView.swift              ← MODIFY: Stage 5 — wire sheets, buttons, enhanced display
```

## Stage Index

| # | Stage | Depends On | Complexity | Status |
|---|-------|-----------|------------|--------|
| 0 | Backend: POS response envelope fix | — | Low | |
| 1 | Models, API Endpoints & PaymentService | Stage 0 | Medium | |
| 2 | Manual Payment Sheet | Stage 1 | Medium | |
| 3 | POS Card Payment + Payment Links | Stage 1 | High | |
| 4 | Buyback Payout Sheet | Stage 1 | Medium | |
| 5 | OrderDetailView Integration | Stages 2, 3, 4 | Medium | |

## Stage Dependency Graph

```
Stage 0 (Backend POS envelope fix)
   └── Stage 1 (Foundation)
          ├── Stage 2 (Manual Payment)     ─┐
          ├── Stage 3 (POS Card Payment)   ─┼── Stage 5 (Integration)
          └── Stage 4 (Buyback Payout)     ─┘
```

Stage 0 is a backend-only change. Stages 2, 3, and 4 are fully independent and can run in parallel after Stage 1.

## API Endpoints Used

### Existing (already in `APIEndpoints.swift`)

| Endpoint | Method | Path | Used By |
|----------|--------|------|---------|
| `createOrderPayment` | POST | `/api/orders/:id/payments` | Stages 2, 4 (via PaymentService) |
| `deleteOrderPayment` | DELETE | `/api/orders/:id/payments/:paymentId` | Stage 5 |

### New (added in Stage 1)

| Endpoint | Method | Path | Used By |
|----------|--------|------|---------|
| `posIntegrations` | GET | `/api/pos/integrations` | Stage 1, Stage 3 |
| `posTerminals` | GET | `/api/pos/terminals` | Stage 3 |
| `initiateTerminalPayment` | POST | `/api/pos/payments` | Stage 3 |
| `pollTerminalPayment` | GET | `/api/pos/payments/:id/status` | Stage 3 |
| `cancelTerminalPayment` | POST | `/api/pos/payments/:id/cancel` | Stage 3 |
| `refundTerminalPayment` | POST | `/api/pos/payments/:id/refund` | Future (refunds) |
| `createPaymentLink` | POST | `/api/pos/payment-links` | Stage 3 |
| `paymentLinks` | GET | `/api/pos/payment-links` | Stage 5 |
| `cancelPaymentLink` | POST | `/api/pos/payment-links/:id/cancel` | Stage 5 |
| `resendPaymentLink` | POST | `/api/pos/payment-links/:id/resend` | Stage 5 |

### Amount Units — CRITICAL

| API Group | Amount Unit | Example |
|-----------|-----------|---------|
| POS endpoints (`/api/pos/*`) | **Pence** (minor units) | `1500` = GBP 15.00 |
| Order payments (`/api/orders/*/payments`) | **Pounds** (major units) | `15.00` = GBP 15.00 |

The iOS app must convert between pounds (UI display) and pence (POS API calls).

## Key Design Decisions

1. **PaymentService as a standalone service** — follows existing pattern in `Core/Services/` (alongside `PasscodeService`, `PushNotificationService`, etc.)
2. **Sheet pattern** — all payment sheets follow `OrderItemFormSheet.swift` conventions: `NavigationStack`, toolbar cancel/action, `presentationDetents`, async `onSave` closure
3. **POS terminal polling** — 2-second interval, 120-second timeout, structured concurrency with `Task` cancellation
4. **State machine for POS payments** — 7 states (select, processing, success, failed, cancelled, timeout, linkCreated)
5. **Deposit auto-detection** — for POS payments, determined by device status (not a user toggle). For manual payments, explicit toggle.
6. **Payment links** — same sheet as POS card payment (mode toggle), separate section in order detail view

## Backend Prerequisites

### 1. POS Response Envelope Fix (Required before Stage 1 testing)

All POS handlers in `worker/pos_handlers.js` return non-standard response envelopes that the iOS `APIClient` cannot decode. The iOS `APIClient.request<T>()` expects `{ success: true, data: T }` but POS handlers return:

- `handleListIntegrations()` → `{ success: true, integrations: [...] }` — must change to `{ success: true, data: [...] }`
- `handleListTerminals()` → `{ success: true, terminals: [...] }` — must change to `{ success: true, data: [...] }`
- `handleInitiatePayment()` → `{ success: true, ...result }` — must change to `{ success: true, data: result }`
- `handlePaymentStatus()` → `{ success: true, ...result }` — must change to `{ success: true, data: result }`
- `handleCancelPayment()` → `{ success: true, ...result }` — must change to `{ success: true, data: result }`
- `handleCreatePaymentLink()` → `{ success: true, ...result }` — must change to `{ success: true, data: result }`
- `handleListPaymentLinks()` → `{ success: true, payment_links: [...] }` — must change to `{ success: true, data: [...] }`
- `handleCancelPaymentLink()` → `{ success: true, ...result }` — must change to `{ success: true, data: result }`
- `handleResendPaymentLinkEmail()` → `{ success: true, ...result }` — must change to `{ success: true, data: result }`

**Lines to change in `worker/pos_handlers.js`:** 182, 391, 448, 472, 495, 558, 614, 645, 668, 692.

The web dashboard must be checked for compatibility — it likely reads the old key names directly. If so, include BOTH keys during transition (e.g., `{ success: true, data: integrations, integrations }`).

### 2. Device Summary Fields (Required before Stage 4 testing)

Stage 4 requires a minor backend update to include `display_name`, `serial_number`, and `payout_amount` in the order detail device summary. This is a single query change in `worker/order_handlers.js` (around line 1254). The `display_name` requires a JOIN on device brands/models, and `payout_amount` maps to the existing `authorisation_amount` column. This can be done any time before Stage 4 testing — Stage 4's Swift code can be written in parallel since the new fields are optional.

## Non-Goals (Future Work)

- POS refunds (endpoint added but UI not implemented)
- Receipt printing
- Apple Pay / Google Pay
- Payment link webhook handling (server-side only)
- Customer-facing payment flow
