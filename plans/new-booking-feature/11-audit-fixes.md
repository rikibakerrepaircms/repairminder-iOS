# Stage 11: Audit Fixes

## Objective

Fix remaining issues identified across 7 audit passes of the booking feature plans (2026-02-06). Most previous audit findings have already been incorporated into the plan files — this covers the outstanding items.

**Status:** Fixes 1–5 have been applied to plan files. Fix 6 is documented here but has NOT yet been applied to Stage 06's code block — see `12-remaining-fixes-prompt.md` for the remaining fixes.

## Dependencies

`[Requires: None]` — These fixes should be applied BEFORE implementing Stages 01–10.

## Complexity

**Low–Medium** — One backend endpoint change (no migration) + iOS plan file updates.

---

## Fix 1: CRITICAL — Backend: Enhance `GET /api/company/public-info`

### Problem

Stage 02's `CompanyPublicInfo` model expects `currencyCode`, `defaultCountryCode`, and `buybackEnabled` from the API. But the backend endpoint only returns 7 fields:

**Current SQL** (`worker/index.js` ~line 10799):
```sql
SELECT id, name, logo_url, vat_number, terms_conditions, privacy_policy
FROM companies WHERE id = ?
```

**Current response:**
```json
{
  "id": "...", "name": "...", "logo_url": "...", "vat_number": "...",
  "terms_conditions": "...", "privacy_policy": "...", "customer_portal_url": "..."
}
```

The iOS model uses `decodeIfPresent` with fallback defaults, so it won't crash — but the dynamic values will never load, making the app always fall back to hardcoded "GBP", "GB", `true`.

### Data already exists — no migration needed

| Field | Source | Already in DB? |
|-------|--------|---------------|
| `currency_code` | `companies.currency_code` | YES (migration 0021, defaults 'GBP') |
| `buyback_enabled` | `companies.buyback_enabled` | YES (migration 0025, defaults 1) |
| `default_country_code` | `company_locations.country_code` WHERE `is_primary = 1` | YES (migration 0002, defaults 'GB') |

The default country code comes from the **primary location**, not a separate column on companies. Every company already has a primary location with a `country_code` field.

### Fix — Update endpoint handler (no migration)

**File:** `worker/index.js`, function `handleCompanyPublicInfo` (~line 10775)

1. Update the SELECT query (~line 10799) to JOIN the primary location:
```sql
SELECT c.id, c.name, c.logo_url, c.vat_number, c.terms_conditions, c.privacy_policy,
       c.currency_code, c.buyback_enabled,
       pl.country_code AS default_country_code
FROM companies c
LEFT JOIN company_locations pl ON pl.company_id = c.id AND pl.is_primary = 1
WHERE c.id = ?
```

2. Add new fields to the response object (~line 10833):
```js
{
  id: company.id,
  name: company.name || null,
  logo_url: company.logo_url || null,
  vat_number: company.vat_number || null,
  terms_conditions: company.terms_conditions || null,
  privacy_policy: company.privacy_policy || null,
  customer_portal_url: customDomain?.hostname ? `https://${customDomain.hostname}` : 'https://app.repairminder.net',
  // NEW — dynamic booking defaults
  currency_code: company.currency_code || 'GBP',
  default_country_code: company.default_country_code || 'GB',
  buyback_enabled: Boolean(company.buyback_enabled)
}
```

3. Deploy worker:
```bash
cd "/Volumes/Riki Repos/repairminder"
npx wrangler deploy
```

### iOS Plan Update (Stage 02)

The `CompanyPublicInfo` model needs updating — remove `defaultCountryName` (derive it from the code on iOS using `Locale`):

**`CompanyPublicInfo` struct** — remove `defaultCountryName` field and its CodingKeys entry. Keep `currencyCode`, `defaultCountryCode`, `buybackEnabled`.

**`BookingViewModel.loadTermsAndConditions()`** — derive country name from code:
```swift
// Replace:
defaultCountryCode = result.defaultCountryCode ?? "GB"
defaultCountryName = result.defaultCountryName ?? "United Kingdom"

// With:
defaultCountryCode = result.defaultCountryCode ?? "GB"
defaultCountryName = Locale(identifier: "en").localizedString(forRegionCode: defaultCountryCode) ?? "United Kingdom"
```

Using `Locale(identifier: "en")` ensures consistent English names regardless of device language (important for addresses stored in the backend).

### Verification

```bash
curl -H "Authorization: Bearer <token>" https://api.repairminder.net/api/company/public-info | jq '.data | {currency_code, default_country_code, buyback_enabled}'
```

Expected: `{"currency_code": "GBP", "default_country_code": "GB", "buyback_enabled": true}`

---

## Fix 2: CRITICAL — iOS Plan: `.client(client.id)` missing argument label

### Problem

In Stage 02 (`02-booking-view-model.md` line 583), `selectClient()` calls:
```swift
let fullClient: Client = try await APIClient.shared.request(.client(client.id))
```

But the `APIEndpoints.swift` enum case is defined as:
```swift
case client(id: String)
```

Swift requires the argument label at the call site for enum associated values. This will fail to compile.

### Fix

**Files to update:**
- `plans/new-booking-feature/02-booking-view-model.md` line 583

Change:
```swift
.client(client.id)
```
To:
```swift
.client(id: client.id)
```

---

## Fix 3: MAJOR — iOS Plan: Double ViewModel + duplicate API calls

### Problem

Both `BookingView` (Stage 03) and `BookingWizardView` (Stage 04) create their own `BookingViewModel` and both call `loadInitialData()`:

**Stage 03** (`03-service-type-selection.md` line 43):
```swift
@State private var viewModel = BookingViewModel()
```
```swift
.task { await viewModel.loadInitialData() }  // line 111
```

**Stage 04** (`04-wizard-container.md` lines 42-48):
```swift
@State private var viewModel: BookingViewModel
init(serviceType: ServiceType) {
    self._viewModel = State(initialValue: BookingViewModel(serviceType: serviceType))
}
```
```swift
.task { await viewModel.loadInitialData() }  // line 95
```

`loadInitialData()` fetches 3 API endpoints (locations, device types, company public info). Since BookingView creates one ViewModel and BookingWizardView creates a separate one, these 3 calls happen **twice** — 6 API calls total instead of 3.

BookingView only needs `buybackEnabled` to filter the service type grid. It doesn't need locations or device types.

### Fix — Pass ViewModel from BookingView to BookingWizardView

**File: `plans/new-booking-feature/03-service-type-selection.md`**

No changes needed to BookingView — it keeps its ViewModel and `.task { await viewModel.loadInitialData() }`.

But change the navigation to pass the ViewModel:
```swift
// Replace (line 97):
BookingWizardView(serviceType: serviceType)

// With:
BookingWizardView(viewModel: viewModel, serviceType: serviceType)
```

**File: `plans/new-booking-feature/04-wizard-container.md`**

Change BookingWizardView to accept an existing ViewModel instead of creating its own:
```swift
struct BookingWizardView: View {
    @Bindable var viewModel: BookingViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: BookingViewModel, serviceType: ServiceType) {
        self.viewModel = viewModel
        viewModel.formData.serviceType = serviceType
    }

    var body: some View {
        // ... same as current plan, but REMOVE the .task { await viewModel.loadInitialData() }
    }
}
```

Key changes:
1. Remove `@State private var viewModel` — use `@Bindable var viewModel` (passed in)
2. Remove the `init` that creates a new ViewModel
3. Remove `.task { await viewModel.loadInitialData() }` (already loaded by BookingView)
4. Set `serviceType` on the existing ViewModel's formData

This eliminates 3 duplicate API calls and ensures data loaded in the service type screen is reused in the wizard.

---

## Fix 4: MAJOR — iOS Plan: `selectClient()` must populate address fields

### Problem

Stage 02's `selectClient()` method (line 568) only populates name, email, phone, and countryCode from the search result. It does NOT populate address fields (addressLine1, addressLine2, city, county, postcode, country).

This is a problem for buyback orders where address is required (`requiresAddress` returns true). Returning customers with an address on file would have to re-type it.

**Root cause:** The client search endpoint (`GET /api/clients/search?email=`) only returns lightweight fields: `id, email, first_name, last_name, phone`. Address fields are NOT in the search response SQL. They ARE available from `GET /api/clients/:id` (the detail endpoint).

### Fix

**File to update:** `plans/new-booking-feature/02-booking-view-model.md`, `selectClient()` method

Replace the current `selectClient()` (lines 568-578) with:

```swift
func selectClient(_ client: Client) {
    // 1. Immediately populate with search result data (fast UX)
    formData.existingClientId = client.id
    formData.existingClient = client
    formData.email = client.email
    formData.firstName = client.firstName ?? ""
    formData.lastName = client.lastName ?? ""
    formData.phone = client.phone ?? ""
    formData.countryCode = client.countryCode ?? defaultCountryCode
    clientSearchResults = []
    clientSearchQuery = ""

    // 2. Fetch full client details in background for address fields
    Task {
        do {
            let fullClient: Client = try await APIClient.shared.request(.client(id: client.id))
            formData.existingClient = fullClient
            formData.addressLine1 = fullClient.addressLine1 ?? ""
            formData.addressLine2 = fullClient.addressLine2 ?? ""
            formData.city = fullClient.city ?? ""
            formData.county = fullClient.county ?? ""
            formData.postcode = fullClient.postcode ?? ""
            formData.country = fullClient.country ?? defaultCountryName
            if let cc = fullClient.countryCode, !cc.isEmpty {
                formData.countryCode = cc
            }
        } catch {
            logger.error("Failed to fetch client details: \(error)")
            // Non-fatal — user can still type address manually
        }
    }
}
```

**Note:** Uses `.client(id: client.id)` — correct argument label per Fix 2.

---

## Fix 5: MAJOR — iOS Plan: `clearSelectedClient()` must reset address fields

### Problem

Stage 02's `clearSelectedClient()` method (line 580) doesn't clear address fields that were populated by Fix 4.

### Fix

**File to update:** `plans/new-booking-feature/02-booking-view-model.md`, `clearSelectedClient()` method

Replace lines 580-588 with:

```swift
func clearSelectedClient() {
    formData.existingClientId = nil
    formData.existingClient = nil
    formData.email = ""
    formData.firstName = ""
    formData.lastName = ""
    formData.phone = ""
    formData.addressLine1 = ""
    formData.addressLine2 = ""
    formData.city = ""
    formData.county = ""
    formData.postcode = ""
    formData.country = defaultCountryName
    formData.countryCode = defaultCountryCode
}
```

---

## Fix 6: MINOR — iOS Plan: Device type picker should filter system types

### Problem

Stage 06's device type picker (`DeviceTypePickerView`) displays ALL types from `viewModel.deviceTypes` without filtering. The backend returns device types including system-created types (where `isSystem == true`) that may not be appropriate for user selection.

### Fix

**File to update:** `plans/new-booking-feature/06-devices-step.md`, device type picker

Filter device types to exclude system types:

```swift
// Where device types are displayed in the picker, use:
let selectableDeviceTypes = viewModel.deviceTypes.filter { $0.isSystem != true }
```

---

## Summary

| # | Severity | Type | Fix |
|---|----------|------|-----|
| 1 | CRITICAL | Backend + iOS plan | JOIN primary location in `GET /api/company/public-info` for `currency_code`, `default_country_code`, `buyback_enabled`. iOS derives country name via `Locale`. No migration. |
| 2 | CRITICAL | iOS plan | `.client(client.id)` → `.client(id: client.id)` — missing argument label |
| 3 | MAJOR | iOS plan | Eliminate double ViewModel — pass from BookingView to BookingWizardView, remove duplicate `loadInitialData()` |
| 4 | MAJOR | iOS plan | `selectClient()` fetches full client via `GET /api/clients/:id` for address |
| 5 | MAJOR | iOS plan | `clearSelectedClient()` resets address fields |
| 6 | MINOR | iOS plan | Filter system device types from picker |

## Implementation Order

1. **Backend first** (Fix 1) — Endpoint update + deploy (no migration)
2. **iOS plan updates** (Fixes 2–6) — Update markdown plans
3. **Then proceed with Stages 01–10**

**Backwards compatible:** The iOS `CompanyPublicInfo` model uses `decodeIfPresent` with fallback defaults, so it works against both the current and enhanced backend.

---

## Previously Fixed (already in plan files from earlier audit passes)

These were identified in earlier audits but have already been incorporated:

- ServiceType enum moved to `Core/Models/ServiceType.swift` in Stage 01
- `.clientSearch` query param fixed from `?q=` to `?email=` in Stage 01
- DeviceType has flexible Bool/Int decoding for `isSystem` in Stage 01
- Buyback icons use `arrow.triangle.2.circlepath` (currency-neutral) in Stages 03/07
- Service type grid filters by `buybackEnabled` in Stage 03
- Client search has 300ms debounce in Stage 05
- Device search has 300ms debounce in Stage 06
- Signature bindings match CustomerSignatureView's 3 required `@Binding` params in Stage 08
- Client search uses `ClientSearchResponse` wrapper (not raw `[Client]`) in Stage 02
- Master plan API table shows correct `?email=` parameter
- Master plan CreateOrderRequest correctly omits `serviceType` (workflow is per-device)
- ServiceType raw values are UI-only labels — `workflowType` on each device is what the backend uses

---

## Acceptance Checklist

### Backend
- [x] `GET /api/company/public-info` JOINs `company_locations` (primary) for `default_country_code`
- [x] Response includes `currency_code`, `default_country_code`, `buyback_enabled`
- [x] `buyback_enabled` is returned as Boolean (not Int)
- [x] No breaking changes to existing web app consumers
- [x] No migration needed (all data already exists)

### iOS Plan Files
- [x] `.client(id: client.id)` — correct argument label everywhere (Fix 2)
- [x] `BookingWizardView` accepts ViewModel from `BookingView` — no duplicate creation (Fix 3)
- [x] `loadInitialData()` only called once in BookingView's `.task` (Fix 3)
- [x] `CompanyPublicInfo` model: remove `defaultCountryName`, keep `currencyCode`, `defaultCountryCode`, `buybackEnabled`
- [x] `loadTermsAndConditions()` derives country name via `Locale(identifier: "en").localizedString(forRegionCode:)`
- [x] `selectClient()` fetches full client details via `GET /api/clients/:id` after selection (Fix 4)
- [x] `selectClient()` populates address fields from full client response (Fix 4)
- [x] `clearSelectedClient()` resets all address fields to defaults (Fix 5)
- [x] Device type picker filters out system types (`isSystem != true`) (Fix 6)
- [x] App works against both current backend (fallback defaults) and enhanced backend (dynamic values)
