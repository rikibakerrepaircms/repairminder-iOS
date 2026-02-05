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
| Feature accessible | Blue plus icon in toolbar (top right) launches the wizard |

---

## Dependencies & Prerequisites

### Required Before Starting
1. ✅ iOS app builds successfully
2. ✅ Authentication working (can make authenticated API calls)
3. ✅ TabView + NavigationStack navigation in place (StaffMainView)
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
| 01 | Models & Endpoints | Create booking models + add APIEndpoint cases | Low |
| 02 | Booking View Model | Create central state management for the wizard | Medium |
| 03 | Service Type Selection | BookingView with 4 service type cards | Low |
| 04 | Wizard Container | BookingWizardView with step navigation and progress | Medium |
| 05 | Client Step | Customer search, creation, and selection | High |
| 06 | Devices Step | Device entry form with brand/model selection | High |
| 07 | Summary Step | Review all data, set ready-by date | Low |
| 08 | Signature Step | Terms agreement and signature capture | Medium |
| 09 | Confirmation Step | Success view with order details | Low |
| 10 | Toolbar Integration | Add blue plus icon to StaffMainView toolbar | Low |

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
│   └── Staff/
│       └── Booking/                          # New feature folder
│           ├── BookingView.swift             # Stage 03 - Service type selection
│           ├── BookingWizardView.swift       # Stage 04 - Wizard container
│           ├── BookingViewModel.swift        # Stage 02 - Central state
│           ├── Steps/
│           │   ├── ClientStepView.swift      # Stage 05
│           │   ├── DevicesStepView.swift     # Stage 06
│           │   ├── SummaryStepView.swift     # Stage 07
│           │   ├── SignatureStepView.swift   # Stage 08
│           │   └── ConfirmationStepView.swift # Stage 09
│           └── Components/
│               ├── ClientSearchView.swift    # Stage 05
│               ├── DeviceEntryFormView.swift # Stage 06
│               ├── BrandModelPicker.swift    # Stage 06
│               └── SignaturePadView.swift    # Stage 08
├── Core/
│   ├── Models/
│   │   ├── Location.swift                    # Stage 01
│   │   ├── Brand.swift                       # Stage 01
│   │   ├── DeviceModel.swift                 # Stage 01
│   │   ├── DeviceType.swift                  # Stage 01
│   │   └── BookingFormData.swift             # Stage 02
│   └── Networking/
│       └── APIEndpoints.swift                # Stage 01 (modify - add new cases)
└── Repair_MinderApp.swift                    # Stage 10 (modify StaffMainView)
```

**Notes:**
- Booking goes inside `Features/Staff/` to match the existing pattern where staff features are organized under that folder (Dashboard, Orders, Devices, etc.).
- `APIEndpoints.swift` is an existing file that needs new enum cases added for booking-related endpoints.

---

## API Endpoints Required

All backend endpoints already exist. Some already have `APIEndpoint` enum cases; others need new cases added.

| Endpoint | Method | Purpose | APIEndpoint Case |
|----------|--------|---------|------------------|
| `/api/clients/search?q=` | GET | Search clients | `.clientSearch(query:)` ✅ exists |
| `/api/clients/:id` | GET | Get client details | `.client(id:)` ✅ exists |
| `/api/clients` | POST | Create new client | `.createClient` ✅ exists |
| `/api/orders` | POST | Create order | `.createOrder` ✅ exists |
| `/api/orders/:id/devices` | POST | Add device to order | `.createOrderDevice(orderId:)` ✅ exists |
| `/api/orders/:id/signatures` | POST | Add signature | `.createOrderSignature(orderId:)` ✅ exists |
| `/api/locations` | GET | Get locations list | `.locations` ⚠️ **add in Stage 01** |
| `/api/brands` | GET | Get brands list | `.brands` ⚠️ **add in Stage 01** |
| `/api/brands/:id/models` | GET | Get models for brand | `.brandModels(brandId:)` ⚠️ **add in Stage 01** |
| `/api/device-types` | GET | Get device types | `.deviceTypes` ⚠️ **add in Stage 01** |

**Note:** Stage 01 must add new cases to `APIEndpoints.swift` for locations, brands, brandModels, and deviceTypes.

### API Client Usage Patterns

Use the `APIEndpoint` enum cases with type-inferred responses:

```swift
// GET request - response type is inferred from the variable type
let locations: [Location] = try await APIClient.shared.request(.locations)

// GET with parameters
let brands: [Brand] = try await APIClient.shared.request(.brands)
let models: [DeviceModel] = try await APIClient.shared.request(.brandModels(brandId: "123"))

// Search clients
let searchResults: ClientSearchResponse = try await APIClient.shared.request(
    .clientSearch(query: "john")
)

// POST request with body - pass body as second parameter
let order: Order = try await APIClient.shared.request(.createOrder, body: createOrderRequest)

// POST device to order
let device: OrderDevice = try await APIClient.shared.request(
    .createOrderDevice(orderId: orderId),
    body: deviceRequest
)
```

**Key patterns:**
- Response type is inferred from the return type (no `responseType:` parameter)
- Encoder auto-converts camelCase → snake_case for request bodies
- Decoder auto-converts snake_case → camelCase for responses
- Use `.convertFromSnakeCase` - don't add explicit raw values in CodingKeys

---

## ViewModel Pattern

Use `@Observable` macro (iOS 17+) for all new ViewModels to match the modern pattern:

```swift
import SwiftUI

@Observable
@MainActor
final class BookingViewModel {
    // State properties (no @Published needed with @Observable)
    private(set) var isLoading = false
    private(set) var error: String?
    var currentStep: BookingStep = .client

    // Form data
    var selectedClient: Client?
    var devices: [BookingDevice] = []

    // Methods
    func loadLocations() async { ... }
    func submitBooking() async throws { ... }
}
```

**View usage:**
```swift
struct BookingWizardView: View {
    @State private var viewModel = BookingViewModel()

    var body: some View {
        // Access viewModel properties directly
    }
}
```

**Key differences from `@ObservableObject`:**
- No `@Published` property wrappers needed
- Use `@State private var` in views (not `@StateObject`)
- Cleaner, less boilerplate code

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
