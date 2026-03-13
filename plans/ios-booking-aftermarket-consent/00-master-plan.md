# iOS Booking: Line Items + Aftermarket Parts Consent

## Feature Overview

Extend the iOS/iPad/Mac booking wizard so staff can **add service line items per device** during booking (Summary step), with an **aftermarket parts consent checkbox** that appears when any device has an aftermarket-tier line item. This brings the Apple apps in line with the web dashboard, which already supports this feature. The backend already handles everything — no API changes needed.

**Why:** Currently the iOS booking flow only captures device details. Staff must add line items separately after booking via the order detail page. This means customers leave without clarity on planned services or parts quality. Adding line items at booking time + aftermarket consent mirrors the web flow and provides a consistent experience regardless of which platform staff use.

## Success Criteria

1. Staff can search and add service products (with tier selection) per device on the Summary step
2. An aftermarket consent checkbox appears per device when any of its line items has `quality_tier` containing "aftermarket" (case-insensitive)
3. Consent is required before proceeding to the Signature step
4. The Signature step shows a summary of all line items per device, with aftermarket acknowledgement noted
5. `aftermarket_consent` is persisted on `order_devices` and line items are created via existing API after order/device creation
6. Customer portal device card shows aftermarket consent acknowledgement
7. All changes compile and run on iPhone, iPad, and Mac (shared code)
8. Existing booking flow works unchanged when no line items are added

## Dependencies & Prerequisites

- Web app Stages 01–06 of `booking-aftermarket-consent` plan — **ALL COMPLETE**
- Backend `aftermarket_consent` column on `order_devices` — **EXISTS** (migration 0322)
- Backend `quality_tier` accepted on `POST /api/orders/:id/items` — **EXISTS**
- Backend `GET /api/product-types/:id/components` returns `quality_tiers` — **EXISTS**
- Existing iOS `OrderItemFormSheet` provides reusable product search patterns
- Existing iOS `ProductTypeSearchResult` model exists in `Order.swift`

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Device creation `requestVoid` discards device IDs | Can't create line items per device | Switch to `request<DeviceCreateResponse>` — backend already returns `{ data: { id } }`. Comment at line 418 anticipated this. |
| Product components endpoint unfamiliar to iOS | Network call might fail or decode wrong | Read backend handler, create minimal response model (only need `quality_tiers`). |
| Summary step becomes cluttered on iPhone | UX degradation | Line items are in a collapsible section per device, "Add Service" is a subtle button. iPad has more room. |
| Line item creation fails after order/device success | Orphaned order without items | Best-effort pattern — log error, staff can add items from Order Detail page (existing flow). |
| Mac target doesn't support product search | Build failure | All code is shared — no platform-specific APIs needed. Product search is pure networking + SwiftUI. |

## Stage Index

| Stage | Name | Complexity | Description |
|-------|------|------------|-------------|
| 01 ✅ | [Model Layer + API Endpoint](01-model-api.md) | Low | Add BookingLineItem, update BookingDeviceEntry, CreateOrderDeviceRequest, OrderItem, OrderItemRequest. Add productComponents endpoint. New ProductComponents.swift. |
| 02 ✅ | [Product Search + Tier Selection UI](02-product-search-ui.md) | Medium | BookingProductSearch, TierSelectionSheet, DeviceLineItemsList — 3 new SwiftUI components. |
| 03 ✅ | [Summary Step — Line Items](03-summary-consent.md) | Medium | Embed line items in SummaryStepView. No consent here — moved to Signature step. |
| 04 ✅ | [Signature Step — Consent + Submission](04-signature-submission.md) | Medium-High | Aftermarket consent checkboxes + planned services on SignatureStepView. Critical: switch submit() to capture device IDs and create line items. |
| 05 ✅ | [Customer Portal + Staff Display](05-customer-portal.md) | Low | Add aftermarketConsent to CustomerDevice, amber notice on CustomerDeviceCard. |

## Parallel Execution

- **Stages 1 + 5 can run in parallel** (Stage 5 only needs model changes, no dependency on UI stages)
- Stages 2 → 3 → 4 are strictly sequential
- Stage 5 depends only on Stage 1 (model field in CustomerDevice)

## Out of Scope

- **Backend changes** — all endpoints and fields already exist
- **Receipt/invoice changes** — iOS fetches these from the backend, web stages 5-6 are already live
- **Company-configurable consent wording** — hardcoded for now (same as web)
- **Aftermarket consent on mail-in bookings** — walk-in only
- **Editing line items after adding** — staff can remove and re-add (edit is post-booking)
- **Auto-allocation during booking** — happens server-side when items are created via existing API
- **Pre-auth auto-calculation from line items** — deferred to a future enhancement
