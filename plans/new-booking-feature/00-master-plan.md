# Master Plan: New Booking Feature for iOS App

## Feature Overview

Implement a full booking wizard in the iOS app that mirrors the web app's `BookingPage.tsx` and `BookingWizard.tsx`. This allows staff to create new repair bookings, buyback transactions, and accessory sales directly from the iOS app without needing to use the web interface.

**Why:** Staff need the ability to create bookings on-the-go, especially for walk-in customers. The booking feature should be instantly accessible from any screen via a persistent branded blue floating action button.

**Reference Implementation:**
- [Ref: /Volumes/Riki Repos/repairminder/src/pages/BookingPage.tsx] - Service type selection
- [Ref: /Volumes/Riki Repos/repairminder/src/components/booking/BookingWizard.tsx] - 5-step wizard + order creation payload
- [Ref: /Volumes/Riki Repos/repairminder/src/components/booking/steps/ClientStep.tsx] - Customer entry with address + location
- [Ref: /Volumes/Riki Repos/repairminder/src/components/booking/steps/DevicesStep.tsx] - Device entry with brand/model
- [Ref: /Volumes/Riki Repos/repairminder/src/components/booking/steps/SummaryStep.tsx] - Review + ready-by date + pre-auth
- [Ref: /Volumes/Riki Repos/repairminder/src/components/booking/steps/SignatureStep.tsx] - Terms + signature capture
- [Ref: /Volumes/Riki Repos/repairminder/src/components/booking/steps/ConfirmationStep.tsx] - Success screen
- [Ref: /Volumes/Riki Repos/repairminder/src/components/ui/SignatureCanvas.tsx] - Canvas-based signature drawing

---

## Success Criteria

| Criteria | Measurement |
|----------|-------------|
| Service type selection works | User can select Repair, Buyback, Accessories, or Device Sale |
| Location selection works | User can select from available locations (auto-selects if only 1) |
| Client search functional | Can search existing clients by name/email/phone |
| New client creation works | Can create new client with email, name, phone, address |
| No-email option works | Can create client without email (generates placeholder) |
| Device entry complete | Can add devices with brand, model, serial, IMEI, condition, issues |
| Multi-device support | Can add multiple devices to a single booking |
| Ready-by date works | Can optionally set a ready-by date and time |
| Pre-authorisation works | Can optionally set a diagnostic/assessment fee amount |
| Terms & conditions display | Fetches and displays company T&Cs from API |
| Signature capture works | Can draw signature on canvas OR type name as fallback |
| Signature stored correctly | Base64 PNG data URL sent inline with order creation (matches web app) |
| Order creation successful | API creates order and devices, returns order number |
| Confirmation displays | Shows order number and success state |
| Build passes | `xcodebuild` completes without errors |
| Feature accessible | Branded blue "New Booking" button visible on all staff tab screens |
| Full-screen experience | Booking wizard presents as a true `.fullScreenCover`, supporting both portrait and landscape, matching the web app's full-page booking flow |

---

## Dependencies & Prerequisites

### Required Before Starting
1. ✅ iOS app builds successfully
2. ✅ Authentication working (can make authenticated API calls)
3. ✅ TabView + NavigationStack navigation in place (StaffMainView)
4. ✅ APIClient and APIEndpoint patterns established
5. ✅ Existing models: Client, Device, Order
6. ✅ Existing reusable component: `CustomerSignatureView` (drawn + typed signature capture with base64 PNG output)

### External Dependencies
- Backend API endpoints exist (verified in web app usage)
- User has staff permissions to create orders

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| API response format differences | High | Medium | Test each endpoint individually, handle edge cases |
| Signature data too large for JSON | Low | Low | Canvas renders at 300x150pt — PNG is small. Web app stores as TEXT with no issues |
| Large form state management | Medium | Low | Use Observable view model, break into sub-states |
| Brand/Model data volume | Low | High | Use `/api/device-search?q=` unified search endpoint — no local data needed |
| Offline booking not supported | Medium | N/A | Out of scope — clearly indicate online-only |

---

## Stage Index

| Stage | Name | Description | Complexity |
|-------|------|-------------|------------|
| 01 | Models & Endpoints | Create booking models + add APIEndpoint cases | Low |
| 02 | Booking View Model | Create central state management for the wizard | Medium |
| 03 | Service Type Selection | BookingView with 4 service type cards | Low |
| 04 | Wizard Container | BookingWizardView with step navigation and progress | Medium |
| 05 | Client Step | Customer search, creation, location, and address | High |
| 06 | Devices Step | Device entry form with unified device search (`/api/device-search`) | High |
| 07 | Summary Step | Review all data, ready-by date, optional pre-auth | Medium |
| 08 | Signature Step | Terms display, agreement, signature capture | Medium |
| 09 | Confirmation Step | Submit order, show success with order details | Medium |
| 10 | Navigation Integration | Add branded blue FAB to all staff tabs + full-screen `.fullScreenCover` presentation | Medium |

---

## Out of Scope

The following are explicitly **NOT** included in this implementation:

1. **Offline booking support** — Bookings require network connectivity
2. **Accessories wizard** — Will show "Coming Soon" placeholder (web app has a separate simplified flow)
3. **Device Sale wizard** — Will show alert directing to buyback list
4. **Email verification** — Simplified validation only
5. **Address autocomplete** — Manual entry only (web uses Google Maps API)
6. **PDF receipt generation** — iOS doesn't need this (web-only)
7. **Sub-location assignment** — Defer to future (requires location setup)
8. **Engineer assignment** — Defer to future

---

## File Structure

```
Repair Minder/
├── Features/
│   └── Staff/
│       └── Booking/                              # New feature folder
│           ├── BookingView.swift                 # Stage 03 - Service type selection
│           ├── BookingWizardView.swift           # Stage 04 - Wizard container
│           ├── BookingViewModel.swift            # Stage 02 - Central state
│           ├── Steps/
│           │   ├── ClientStepView.swift          # Stage 05
│           │   ├── DevicesStepView.swift         # Stage 06
│           │   ├── SummaryStepView.swift         # Stage 07
│           │   ├── SignatureStepView.swift       # Stage 08
│           │   └── ConfirmationStepView.swift    # Stage 09
│           └── Components/
│               ├── ClientSearchView.swift        # Stage 05
│               ├── DeviceEntryFormView.swift     # Stage 06
│               └── DeviceSearchPicker.swift      # Stage 06 - unified brand/model search
├── Core/
│   ├── Models/
│   │   ├── Location.swift                        # Stage 01 (NOTE: LocationOption already exists in DeviceQueueItem.swift — this adds the full Location model with country_code)
│   │   ├── DeviceSearchResult.swift              # Stage 01 - response model for /api/device-search
│   │   ├── DeviceType.swift                      # Stage 01 (NOTE: DeviceTypeOption already exists — this is an alias or extension)
│   │   └── BookingFormData.swift                 # Stage 02
│   └── Networking/
│       └── APIEndpoints.swift                    # Stage 01 (modify - add new cases)
├── Features/
│   └── Customer/
│       └── Components/
│           └── CustomerSignatureView.swift       # EXISTING - reuse for signature capture
└── Features/
    └── Staff/
        ├── StaffMainView.swift                   # Stage 10 (modify - add branded blue FAB overlay + fullScreenCover)
        └── Dashboard/
            └── DashboardView.swift               # EXISTING - no modification needed
```

**Notes:**
- Booking goes inside `Features/Staff/` to match the existing pattern.
- `CustomerSignatureView.swift` already exists with drawn (base64 PNG) + typed (name) support — reuse it in `SignatureStepView` rather than creating a new component.
- No separate `SignaturePadView` needed — the existing component already handles canvas drawing, clear, and base64 encoding.
- The "New Booking" button is a branded blue floating action button (FAB) added as an overlay in `StaffMainView`, so it appears on **all** staff tabs (Dashboard, Devices, Queue, etc.). It triggers a `.fullScreenCover` that supports both portrait and landscape.
- `LocationOption` (id, name) and `DeviceTypeOption` (id, name, slug) already exist in `DeviceQueueItem.swift` — reuse or extend these rather than duplicating.

---

## API Endpoints Required

All backend endpoints already exist (verified via web app). Some already have `APIEndpoint` enum cases; others need new cases added.

| Endpoint | Method | Purpose | APIEndpoint Case |
|----------|--------|---------|------------------|
| `/api/clients/search?email=` | GET | Search clients | `.clientSearch(query:)` ✅ exists |
| `/api/clients/:id` | GET | Get client details | `.client(id:)` ✅ exists |
| `/api/clients` | POST | Create new client | `.createClient` ✅ exists |
| `/api/orders` | POST | Create order (with inline signature) | `.createOrder` ✅ exists |
| `/api/orders/:id/devices` | POST | Add device to order | `.createOrderDevice(orderId:)` ✅ exists |
| `/api/locations` | GET | Get locations list | `.locations` ⚠️ **add in Stage 01** |
| `/api/device-search?q=` | GET | Search brands + models (unified) | `.deviceSearch(query:)` ⚠️ **add in Stage 01** |
| `/api/device-types` | GET | Get device types | `.deviceTypes` ⚠️ **add in Stage 01** |
| `/api/company/public-info` | GET | Get company name + T&Cs | `.companyPublicInfo` ⚠️ **add in Stage 01** |

**Important — No separate `/api/brands` endpoint exists:**
The web app uses a **unified search** endpoint `GET /api/device-search?q=<query>` (see `DeviceSearch.tsx`) which returns `{ brands: [...], models: [...] }` in a single response. Users type a search query (e.g. "iPhone") and get matching brands and models together. There is no browse-by-brand flow.

**Important — Signature is NOT a separate API call:**
The web app sends signature data **inline** with the `POST /api/orders` payload. The existing `.createOrderSignature(orderId:)` endpoint is for adding signatures to existing orders (e.g., collection signatures) — it is NOT used during booking creation.

---

## Order Creation Payload (matches web app)

The `POST /api/orders` request body must match this structure:

```swift
struct CreateOrderRequest: Encodable {
    let clientEmail: String?
    let noEmail: Bool?
    let clientFirstName: String
    let clientLastName: String?
    let clientPhone: String?
    let clientCountryCode: String?

    // Address fields
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let country: String?

    let locationId: String?
    let intakeMethod: String          // Always "walk_in" for booking wizard
    let readyBy: String?              // ISO format: "YYYY-MM-DDTHH:MM:SS"
    let existingTicketId: String?     // Link to existing enquiry/ticket (optional)

    // Inline signature (NOT a separate API call)
    let signature: SignaturePayload

    // Optional pre-authorisation
    let preAuthorization: PreAuthPayload?
}

struct SignaturePayload: Encodable {
    let signatureData: String?        // Base64 PNG data URL from canvas, or nil
    let typedName: String?            // Typed name string, or nil
    let signatureMethod: String       // "drawn" or "typed"
    let termsAgreed: Bool             // Must be true
    let marketingConsent: Bool
    let userAgent: String             // e.g. "RepairMinder-iOS/1.0"
    let geolocation: GeoPayload?      // Optional device location
}

struct GeoPayload: Encodable {
    let latitude: Double
    let longitude: Double
}

struct PreAuthPayload: Encodable {
    let amount: Double
    let notes: String?
    let authorizedAt: String          // ISO timestamp
}
```

**Backend behaviour on receiving this:**
1. Creates/finds client from the client fields
2. Creates the order record
3. Inserts a row into `order_signatures` with `signature_type = 'drop_off'`
4. Stores signature as base64 text, captures IP from CF headers, snapshots T&Cs
5. Returns `{ success: true, data: { id, order_number } }`

**Then for each device:**
`POST /api/orders/{orderId}/devices` with device payload (called sequentially per device).

---

## Add Device Payload

```swift
struct CreateOrderDeviceRequest: Encodable {
    let brandId: String?
    let modelId: String?
    let customBrand: String?          // If not using brandId
    let customModel: String?          // If not using modelId
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let storageCapacity: String?
    let passcode: String?
    let passcodeType: String?         // "none", "pin", "pattern", "password", "biometric"
    let findMyStatus: String?         // "enabled", "disabled", "unknown"
    let conditionGrade: String?
    let customerReportedIssues: String?
    let deviceTypeId: String?
    let workflowType: String?         // "repair" or "buyback" (defaults to order serviceType)
    let accessories: [AccessoryItem]?
}

struct AccessoryItem: Encodable {
    let accessoryType: String
    let description: String
}
```

---

## API Client Usage Patterns

Use the `APIEndpoint` enum cases with type-inferred responses:

```swift
// GET request - response type is inferred from the variable type
let locations: [Location] = try await APIClient.shared.request(.locations)

// Unified device search - returns brands + models matching query
let searchResults: DeviceSearchResponse = try await APIClient.shared.request(
    .deviceSearch(query: "iPhone")
)
// searchResults.brands: [DeviceSearchBrand]
// searchResults.models: [DeviceSearchModel]

// Search clients (returns ClientSearchResponse wrapper)
let result: ClientSearchResponse = try await APIClient.shared.request(
    .clientSearch(query: "john")
)
let clients = result.clients

// POST request with body - pass body as second parameter
let order: CreateOrderResponse = try await APIClient.shared.request(
    .createOrder, body: createOrderRequest
)

// POST device to order (returns { id } but we don't need it)
try await APIClient.shared.requestVoid(
    .createOrderDevice(orderId: orderId),
    body: deviceRequest
)
```

**Key patterns:**
- Response type is inferred from the return type (no `responseType:` parameter)
- Encoder auto-converts camelCase → snake_case for request bodies
- Decoder auto-converts snake_case → camelCase for responses
- Use `.convertFromSnakeCase` — don't add explicit raw values in CodingKeys

---

## Signature Capture — Matching the Web App

The web app stores signatures as follows:

| Field | Value | Notes |
|-------|-------|-------|
| `signature_data` | `data:image/png;base64,iVBORw0KG...` | Base64 PNG data URL from canvas |
| `typed_name` | `"John Smith"` | Alternative to drawn signature |
| `signature_method` | `"drawn"` or `"typed"` | How signature was captured |
| `terms_agreed` | `1` | Boolean — must be true |
| `marketing_consent` | `0` or `1` | Optional |
| `user_agent` | Browser/app identifier | Audit trail |
| `geolocation` | `{"latitude":51.5,"longitude":-0.1}` | Optional, JSON string |
| `ip_address` | Captured server-side | From CF-Connecting-IP header |
| `terms_snapshot` | JSON of T&Cs at signing time | Captured server-side |

**iOS implementation (reusing `CustomerSignatureView`):**

The existing `CustomerSignatureView` already:
- ✅ Supports drawn signatures via SwiftUI Canvas with DragGesture
- ✅ Renders to `UIImage` via `ImageRenderer` at 3x scale
- ✅ Converts to base64 PNG data URL: `"data:image/png;base64," + data.base64EncodedString()`
- ✅ Supports typed name with cursive preview (Snell Roundhand font)
- ✅ Has a `signatureData` computed property returning the correct format
- ✅ Has `isValid` validation
- ✅ Has clear button for drawn signatures

The `SignatureStepView` (Stage 08) wraps this component with:
- Terms & conditions text (fetched from `/api/company/public-info`)
- Terms agreement checkbox (required)
- Marketing consent checkbox (optional, default true)
- The signature capture component itself

No new signature drawing component is needed.

---

## ViewModel Pattern

Use `@Observable` macro (iOS 17+) for all new ViewModels to match the modern pattern used by `DashboardViewModel`:

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

| Stage | Estimated Effort | Dependencies |
|-------|------------------|--------------|
| 01 | Small | None |
| 02 | Medium | Stage 01 |
| 03 | Small | None |
| 04 | Medium | Stage 02, 03 |
| 05 | Large | Stage 01, 02, 04 |
| 06 | Large | Stage 01, 02, 04 |
| 07 | Medium | Stage 02, 04 |
| 08 | Medium | Stage 02, 04 |
| 09 | Medium | Stage 02, 04 |
| 10 | Medium | All stages |

---

## Testing Strategy

1. **Build verification** — Each stage must compile without errors
2. **Manual testing** — Run in simulator, walk through full booking flow
3. **Integration testing** — Create actual booking on staging environment with real API
4. **Signature verification** — Confirm drawn signature arrives in backend as valid base64 PNG
5. **Edge cases** — No email flow, buyback with address, multiple devices, typed vs drawn signature

---

## Deployment

1. Implement stages sequentially (01 → 10)
2. Build and test after each stage
3. Full end-to-end test on staging API
4. Build for TestFlight
5. QA testing
6. Merge to main
7. App Store release
