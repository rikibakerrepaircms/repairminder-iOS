# Master Plan: New Booking Feature for iOS App

## Feature Overview

Implement a full booking wizard in the iOS app that mirrors the web app's `BookingPage.tsx` and `BookingWizard.tsx`. This allows staff to create new repair bookings, buyback transactions, and accessory sales directly from the iOS app without needing to use the web interface.

**Why:** Currently, the "New Order" quick action button on the dashboard only shows a placeholder. Staff need the ability to create bookings on-the-go, especially for walk-in customers.

**Reference Implementation:**
- [Ref: /Volumes/Riki Repos/repairminder/src/pages/BookingPage.tsx] - Service type selection
- [Ref: /Volumes/Riki Repos/repairminder/src/components/booking/BookingWizard.tsx] - 5-step wizard
- [Ref: /Volumes/Riki Repos/repairminder/src/components/booking/steps/ClientStep.tsx] - Customer entry
- [Ref: /Volumes/Riki Repos/repairminder/src/components/booking/steps/DevicesStep.tsx] - Device entry

---

## Success Criteria

| Criteria | Measurement |
|----------|-------------|
| Service type selection works | User can select Repair, Buyback, Accessories, or Device Sale |
| Client search functional | Can search existing clients by name/email/phone |
| New client creation works | Can create new client with email, name, phone, address |
| Device entry complete | Can add devices with brand, model, serial, IMEI, condition, issues |
| Multi-device support | Can add multiple devices to a single booking |
| Signature capture works | Can capture customer signature on device |
| Order creation successful | API creates order and devices, returns order number |
| Confirmation displays | Shows order number and success state |
| Build passes | `xcodebuild` completes without errors |
| Feature accessible | "New Booking" button on dashboard launches the wizard |

---

## Dependencies & Prerequisites

### Required Before Starting
1. ✅ iOS app builds successfully
2. ✅ Authentication working (can make authenticated API calls)
3. ✅ AppRouter navigation system in place
4. ✅ APIClient and APIEndpoint patterns established
5. ✅ Existing models: Client, Device, Order

### External Dependencies
- Backend API endpoints exist (verified in web app usage)
- User has staff permissions to create orders

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| API response format differences | High | Medium | Test each endpoint individually, handle edge cases |
| Signature capture complexity | Medium | Medium | Use native PencilKit or simple canvas drawing |
| Large form state management | Medium | Low | Use Observable view model, break into sub-states |
| Brand/Model data volume | Low | High | Implement search with API filtering, not local |
| Offline booking not supported | Medium | N/A | Out of scope - clearly indicate online-only |

---

## Stage Index

| Stage | Name | Description | Complexity |
|-------|------|-------------|------------|
| 01 | Models | Create booking models (Location, Brand, DeviceModel, DeviceType) | Low |
| 02 | Booking View Model | Create central state management for the wizard | Medium |
| 03 | Service Type Selection | BookingView with 4 service type cards | Low |
| 04 | Wizard Container | BookingWizardView with step navigation and progress | Medium |
| 05 | Client Step | Customer search, creation, and selection | High |
| 06 | Devices Step | Device entry form with brand/model selection | High |
| 07 | Summary Step | Review all data, set ready-by date | Low |
| 08 | Signature Step | Terms agreement and signature capture | Medium |
| 09 | Confirmation Step | Success view with order details | Low |
| 10 | Dashboard Integration | Wire up "New Booking" button, navigation routes | Low |

---

## Out of Scope

The following are explicitly **NOT** included in this implementation:

1. **Offline booking support** - Bookings require network connectivity
2. **Accessories wizard** - Will show "Coming Soon" placeholder
3. **Device Sale wizard** - Will show alert directing to buyback list
4. **Ticket linking** - Complex feature from web, defer to future
5. **Email verification** - Simplified validation only
6. **Address autocomplete** - Manual entry only
7. **Pre-authorization** - Payment feature, defer to future
8. **PDF receipt generation** - iOS doesn't need this (web-only)
9. **Sub-location assignment** - Defer to future (requires location setup)
10. **Engineer assignment** - Defer to future

---

## File Structure

```
Repair Minder/
├── Features/
│   └── Booking/
│       ├── BookingView.swift                 # Stage 03
│       ├── BookingWizardView.swift           # Stage 04
│       ├── BookingViewModel.swift            # Stage 02
│       ├── Steps/
│       │   ├── ClientStepView.swift          # Stage 05
│       │   ├── DevicesStepView.swift         # Stage 06
│       │   ├── SummaryStepView.swift         # Stage 07
│       │   ├── SignatureStepView.swift       # Stage 08
│       │   └── ConfirmationStepView.swift    # Stage 09
│       └── Components/
│           ├── ClientSearchView.swift        # Stage 05
│           ├── DeviceEntryFormView.swift     # Stage 06
│           ├── BrandModelPicker.swift        # Stage 06
│           └── SignaturePadView.swift        # Stage 08
├── Core/
│   └── Models/
│       ├── Location.swift                    # Stage 01
│       ├── Brand.swift                       # Stage 01
│       ├── DeviceModel.swift                 # Stage 01
│       ├── DeviceType.swift                  # Stage 01
│       └── BookingFormData.swift             # Stage 02
└── Features/
    └── Dashboard/
        └── Components/
            └── QuickActionsView.swift        # Stage 10 (modify)
```

---

## API Endpoints Required

All backend endpoints already exist. Use `APIEndpoint(path:)` directly - **no new Swift definitions needed**.

| Endpoint | Method | Purpose | Usage |
|----------|--------|---------|-------|
| `/api/clients?search=` | GET | Search clients | `clients(search:)` exists |
| `/api/clients/:id` | GET | Get client details | `client(id:)` exists |
| `/api/orders` | POST | Create order | `createOrder(body:)` exists |
| `/api/locations` | GET | Get locations list | `APIEndpoint(path: "/api/locations")` |
| `/api/brands` | GET | Get brands list | `APIEndpoint(path: "/api/brands")` |
| `/api/brands/:id/models` | GET | Get models for brand | `APIEndpoint(path: "/api/brands/\(brandId)/models")` |
| `/api/device-types` | GET | Get device types | `APIEndpoint(path: "/api/device-types")` |
| `/api/orders/:id/devices` | POST | Add device to order | `APIEndpoint(path: "/api/orders/\(orderId)/devices", method: .post, body: ...)` |

**Note:** No changes to `APIEndpoints.swift` required. Just use inline `APIEndpoint(path:)` for endpoints without existing definitions.

### API Client Usage Patterns

Use `APIEndpoint(path:)` directly - no new definitions needed:

```swift
// GET request - use APIEndpoint(path:) directly
let locations = try await APIClient.shared.request(
    APIEndpoint(path: "/api/locations"),
    responseType: [Location].self
)

// POST request with body
try await APIClient.shared.requestVoid(
    APIEndpoint(path: "/api/orders/\(orderId)/devices", method: .post, body: deviceRequest)
)

// Use existing definitions where available
let response = try await APIClient.shared.request(
    .clients(search: query),
    responseType: ClientsListData.self
)
let clients = response.clients  // Access nested array
```

- Encoder auto-converts camelCase to snake_case for request bodies
- Decoder auto-converts snake_case to camelCase for responses

---

## Estimated Effort

| Stage | Estimated Time | Dependencies |
|-------|----------------|--------------|
| 01 | 1 session | None |
| 02 | 1 session | Stage 01 |
| 03 | 0.5 session | None |
| 04 | 1 session | Stage 02, 03 |
| 05 | 2 sessions | Stage 01, 02, 04 |
| 06 | 2 sessions | Stage 01, 02, 04 |
| 07 | 0.5 session | Stage 02, 04 |
| 08 | 1.5 sessions | Stage 02, 04 |
| 09 | 0.5 session | Stage 02, 04 |
| 10 | 0.5 session | All stages |
| **Total** | **~10 sessions** | |

---

## Testing Strategy

1. **Unit testing** - View models with mock API responses
2. **UI testing** - Navigation flow through wizard steps
3. **Integration testing** - Create actual booking on staging environment
4. **Manual testing** - Full end-to-end with real device

---

## Deployment

1. Merge all stages to feature branch
2. Run full test suite
3. Build for TestFlight
4. QA testing on staging API
5. Merge to main
6. App Store release
