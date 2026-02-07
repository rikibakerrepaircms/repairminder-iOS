# Final Audit Fix Prompt — New Booking Feature Plans

> **Context:** This is the output of the 3rd audit pass (2026-02-06), conducted after `11-audit-fixes.md` (Fixes 1-6) and `12-remaining-fixes-prompt.md` (Fixes A-D) were already applied to the plan files. Every fix below is **NEW** — not covered by prior audits.
>
> **What you're editing:** Plan markdown files with embedded Swift code blocks. NOT actual Swift source files. These plans will be used to implement the feature.
>
> **How to work:** Apply fixes stage by stage. After each stage, re-read the modified file and run the self-check listed. Only proceed to the next stage after confirming all checks pass. If anything is unclear, stop and ask.

---

## Stage 02 Fixes (`plans/new-booking-feature/02-booking-view-model.md`)

Stage 02 has 6 fixes. Apply in order.

### Fix 1 — CRITICAL: `requiresAddress` must also check `serviceType`

**Problem:** For buyback bookings, `requiresAddress` is `false` during the Client step (step 1) because no devices exist yet — they're added on step 2. The address section won't appear and won't be validated. The user passes step 1, adds buyback devices on step 2, then has to go back to step 1 to fill in the address. Bad UX and the backend will reject the order if address is missing.

**Find this code** in the `BookingFormData` struct (currently around line 251):
```swift
    var requiresAddress: Bool {
        devices.contains { $0.workflowType == .buyback }
    }
```

**Replace with:**
```swift
    var requiresAddress: Bool {
        serviceType == .buyback || devices.contains { $0.workflowType == .buyback }
    }
```

**Why this works:** `serviceType` is already a property on `BookingFormData` (`var serviceType: ServiceType = .repair`). For buyback orders, the address section now shows immediately on step 1. For repair orders with a single buyback device added later, the existing device check still triggers it.

---

### Fix 2 — CRITICAL: Add `accessories` to `BookingDeviceEntry` and `CreateOrderDeviceRequest`

**Problem:** The master plan (`00-master-plan.md` lines 259-266) specifies an `accessories` field on the device request, and the backend (`device_handlers.js` ~line 1235) accepts `accessories: [{ accessory_type, description }]`. But neither `BookingDeviceEntry` nor the device request struct include it.

**Step 2a** — In the `BookingDeviceEntry` struct, find `var workflowType: WorkflowType` and add after it:
```swift
    var accessories: [BookingAccessoryItem]
```

**Step 2b** — Add this struct immediately after `BookingDeviceEntry`'s closing brace (before `/// Complete form data for a booking`):
```swift
/// An accessory item attached to a device during booking
struct BookingAccessoryItem: Identifiable, Equatable {
    let id: UUID
    var accessoryType: String    // "charger", "cable", "case", "sim_card", "box", "other"
    var description: String

    static func empty() -> BookingAccessoryItem {
        BookingAccessoryItem(id: UUID(), accessoryType: "other", description: "")
    }
}
```

**Step 2c** — Update `BookingDeviceEntry.empty()` — find the existing `static func empty(...)` and add `accessories: []` to the initializer, after `workflowType: workflowType`:
```swift
            workflowType: workflowType,
            accessories: []
```

**Step 2d** — In `AddDeviceRequest` (or `CreateOrderDeviceRequest` if already renamed), add after `let workflowType: String`:
```swift
    let accessories: [AccessoryPayload]?
```

**Step 2e** — Add this struct after `AddDeviceRequest`:
```swift
struct AccessoryPayload: Encodable {
    let accessoryType: String
    let description: String
}
```

**Step 2f** — In the `submit()` method's device loop, update the device request construction. Find where `workflowType: device.workflowType.rawValue` appears and add after it:
```swift
                    accessories: device.accessories.isEmpty ? nil : device.accessories.map {
                        AccessoryPayload(accessoryType: $0.accessoryType, description: $0.description)
                    }
```

---

### Fix 3 — MAJOR: Remove dead `sigData` variable

**Problem:** In the `submit()` method, `let sigData = formData.signatureData` is computed but never used. The actual signature construction uses `formData.signatureData` directly. Dead code.

**Find and delete these 3 lines** (around line 681-683):
```swift
            // 3. Compute signature data from CustomerSignatureView bindings
            // formData.signatureData is a computed property that returns base64 data URL or typed name
            let sigData = formData.signatureData
```

Renumber the subsequent comment from `// 3b.` to `// 3.`.

---

### Fix 4 — MAJOR: Add `signatureMethod` to `SignatureData`

**Problem:** The backend stores `signature_method` (`"drawn"` or `"typed"`) in the `order_signatures` table. The web app sends it explicitly. Without it, the backend stores null for this audit column.

**Find** the `CreateOrderRequest.SignatureData` nested struct:
```swift
    struct SignatureData: Encodable {
        let signatureData: String?
        let typedName: String?
        let termsAgreed: Bool
        let marketingConsent: Bool
        let userAgent: String
        let geolocation: GeoPayload?
    }
```

**Replace with:**
```swift
    struct SignatureData: Encodable {
        let signatureData: String?
        let typedName: String?
        let signatureMethod: String    // "drawn" or "typed"
        let termsAgreed: Bool
        let marketingConsent: Bool
        let userAgent: String
        let geolocation: GeoPayload?
    }
```

---

### Fix 5 — MAJOR: Fix signature mutual exclusivity + add `signatureMethod` to submit

**Problem:** In drawn mode, the submit could send a stale `typedName` (if user typed something before switching to drawn). Also needs the new `signatureMethod` field from Fix 4.

**Find** in the `submit()` method the `CreateOrderRequest.SignatureData(...)` construction:
```swift
                signature: CreateOrderRequest.SignatureData(
                    signatureData: formData.signatureType == .drawn ? formData.signatureData : nil,
                    typedName: formData.typedName.isEmpty ? nil : formData.typedName,
                    termsAgreed: formData.termsAgreed,
```

**Replace with:**
```swift
                signature: CreateOrderRequest.SignatureData(
                    signatureData: formData.signatureType == .drawn ? formData.signatureData : nil,
                    typedName: formData.signatureType == .typed && !formData.typedName.isEmpty ? formData.typedName : nil,
                    signatureMethod: formData.signatureType.rawValue,
                    termsAgreed: formData.termsAgreed,
```

**What changed:**
1. `typedName:` now only sends a value when `signatureType == .typed` (prevents stale data in drawn mode)
2. `signatureMethod:` sends `"drawn"` or `"typed"` from the enum rawValue

---

### Fix 6 — MINOR: Rename `AddDeviceRequest` → `CreateOrderDeviceRequest`

**Problem:** Master plan uses `CreateOrderDeviceRequest`, Stage 02 uses `AddDeviceRequest`. Inconsistent.

**Action:** Find every occurrence of `AddDeviceRequest` in the file and rename to `CreateOrderDeviceRequest`. There should be 2 occurrences:
1. The struct declaration: `struct AddDeviceRequest: Encodable {`
2. The usage in submit(): `let deviceRequest = AddDeviceRequest(`

---

### Stage 02 — Self-Check ✅

Re-read the file after all 6 fixes. Confirm each:

| # | Check | How to verify |
|---|-------|---------------|
| 1 | `requiresAddress` references `serviceType` | Search for `serviceType == .buyback` inside `requiresAddress` |
| 2 | `BookingDeviceEntry` has `accessories` field | Search for `var accessories: \[BookingAccessoryItem\]` |
| 3 | `BookingAccessoryItem` struct exists | Search for `struct BookingAccessoryItem` |
| 4 | `BookingDeviceEntry.empty()` includes `accessories: []` | Check the static factory method |
| 5 | `CreateOrderDeviceRequest` has `accessories: [AccessoryPayload]?` | Search for `AccessoryPayload` |
| 6 | `AccessoryPayload` struct exists | Search for `struct AccessoryPayload` |
| 7 | No `let sigData` line exists | Search for `sigData` — 0 results |
| 8 | `SignatureData` has 7 fields (includes `signatureMethod`) | Count fields in the struct |
| 9 | Submit sends `signatureMethod: formData.signatureType.rawValue` | Check the SignatureData construction |
| 10 | Submit sends `typedName` only when `.typed` | Check the ternary includes `signatureType == .typed` |
| 11 | Zero occurrences of `AddDeviceRequest` | Search for it — 0 results |
| 12 | Device loop in submit includes `accessories:` | Check the request construction |

**Say "Stage 02: all 12 checks pass" before continuing.**

---

## Stage 00 Fixes (`plans/new-booking-feature/00-master-plan.md`)

### Fix 7 — Update master plan's device payload to include passcode/findMy fields

**Problem:** The "Add Device Payload" section (lines ~246-266) is missing `passcode`, `passcodeType`, and `findMyStatus` that Stage 02 sends and the backend accepts.

**Find** the `CreateOrderDeviceRequest` struct in the "Add Device Payload" section and **replace the entire struct** with:
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

### Fix 8 — Add `signatureMethod` to master plan's `SignaturePayload`

**Find** the `SignaturePayload` struct in the "Order Creation Payload" section. Add after the `typedName` line:
```swift
    let signatureMethod: String       // "drawn" or "typed"
```

---

### Fix 9 — Update master plan API usage to use `requestVoid` for devices

**Find** in the "API Client Usage Patterns" section:
```swift
// POST device to order
let device: OrderDevice = try await APIClient.shared.request(
    .createOrderDevice(orderId: orderId),
    body: deviceRequest
)
```

**Replace with:**
```swift
// POST device to order (returns { id } but we don't need it)
try await APIClient.shared.requestVoid(
    .createOrderDevice(orderId: orderId),
    body: deviceRequest
)
```

---

### Stage 00 — Self-Check ✅

| # | Check |
|---|-------|
| 1 | `CreateOrderDeviceRequest` in master plan has `passcode`, `passcodeType`, `findMyStatus` |
| 2 | `SignaturePayload` has `signatureMethod` field |
| 3 | API usage example uses `requestVoid` (not typed `request`) for device addition |
| 4 | `AccessoryItem` struct exists in the master plan |

**Say "Stage 00: all 4 checks pass" before continuing.**

---

## Stage 06 Fixes (`plans/new-booking-feature/06-devices-step.md`)

### Fix 10 — Add accessories section to `DeviceEntryFormView`

**Problem:** Now that `BookingDeviceEntry` has accessories (Fix 2), the device entry form needs UI to add/remove them.

**Find** in `DeviceEntryFormView` the "Workflow Type" section (the `if viewModel.formData.serviceType == .repair {` block). **After its closing brace** and before the "Save Button" section (`// Save Button`), add:

```swift
            // Accessories
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Accessories Included")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        device.accessories.append(BookingAccessoryItem.empty())
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                            .font(.caption)
                    }
                }

                if !device.accessories.isEmpty {
                    ForEach($device.accessories) { $accessory in
                        HStack(spacing: 8) {
                            Picker("Type", selection: $accessory.accessoryType) {
                                Text("Charger").tag("charger")
                                Text("Cable").tag("cable")
                                Text("Case").tag("case")
                                Text("SIM Card").tag("sim_card")
                                Text("Box").tag("box")
                                Text("Other").tag("other")
                            }
                            .pickerStyle(.menu)

                            TextField("Description (optional)", text: $accessory.description)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                device.accessories.removeAll { $0.id == accessory.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
```

---

### Fix 11 — Show accessory count in `DeviceListItemView`

**Find** in `DeviceListItemView` the section that shows `customerReportedIssues`. **After its closing brace**, add:

```swift
                if !device.accessories.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bag")
                        Text("\(device.accessories.count) accessor\(device.accessories.count == 1 ? "y" : "ies")")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
```

---

### Fix 12 — Update ALL `BookingDeviceEntry(...)` preview literals in Stage 06

Every manually constructed `BookingDeviceEntry(...)` literal in the file needs `accessories: []` as the last parameter before the closing `)`. There are 2 occurrences:

1. **`DeviceListItemView` preview** (around line 516-534) — add `accessories: []` after `workflowType: .repair`
2. **Any other manual `BookingDeviceEntry(...)` literals** — same treatment

`BookingDeviceEntry.empty()` calls (used in `DeviceEntryFormView.init`) already get `accessories: []` from Fix 2c, so no change needed there.

---

### Stage 06 — Self-Check ✅

| # | Check |
|---|-------|
| 1 | `DeviceEntryFormView` has "Accessories Included" section with add/remove UI |
| 2 | `DeviceListItemView` shows accessory count when `device.accessories` is non-empty |
| 3 | All `BookingDeviceEntry(...)` preview literals include `accessories: []` |
| 4 | `DeviceEntryFormView` references `BookingAccessoryItem.empty()` (defined in Stage 02) |

**Say "Stage 06: all 4 checks pass" before continuing.**

---

## Stage 07 Fixes (`plans/new-booking-feature/07-summary-step.md`)

### Fix 13 — Show accessories in `DeviceSummaryCard`

**Find** in `DeviceSummaryCard` the `HStack` that shows condition/findMy/passcode labels. **After its closing brace**, add:

```swift
                if !device.accessories.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bag")
                        Text("Accessories: \(device.accessories.map(\.accessoryType).joined(separator: ", "))")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
```

---

### Fix 14 — Fix double background on Internal Notes

**Find** the Internal Notes section's `TextField`:
```swift
                TextField("e.g. Customer mentioned they need it back by Friday", text: $viewModel.formData.internalNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color(.systemGray6))
```

**Change** the `.background` to:
```swift
                    .background(Color(.systemBackground))
```

This gives the text field visual contrast against its `systemGray6` parent container.

---

### Fix 15 — Update preview `BookingDeviceEntry(...)` literal

**Find** the `BookingDeviceEntry(...)` literal in the `#Preview` at the bottom. Add `accessories: []` after `workflowType: .repair`.

---

### Stage 07 — Self-Check ✅

| # | Check |
|---|-------|
| 1 | `DeviceSummaryCard` shows accessories line when present |
| 2 | Internal Notes TextField uses `Color(.systemBackground)` not `Color(.systemGray6)` |
| 3 | Preview's `BookingDeviceEntry(...)` has `accessories: []` |

**Say "Stage 07: all 3 checks pass" before continuing.**

---

## Stage 05 Fix (`plans/new-booking-feature/05-client-step.md`)

### Fix 16 — Update handoff notes about `requiresAddress`

**Find** in the Handoff Notes section:
```
- [See: Stage 06] Devices step may trigger address requirement for buyback
```

**Replace with:**
```
- Address section shows automatically for buyback service type (`requiresAddress` checks `serviceType == .buyback`)
- Address also shows if any individual device has `workflowType == .buyback` (for mixed repair+buyback orders)
- [See: Stage 06] Adding buyback devices on a repair order also triggers address requirement
```

---

### Stage 05 — Self-Check ✅

| # | Check |
|---|-------|
| 1 | Handoff notes mention `serviceType == .buyback` triggering address |

**Say "Stage 05: check passes" before continuing.**

---

## Stages with NO fixes needed

Confirm these stages require no changes:
- **Stage 01** (`01-models-and-api-endpoints.md`) — All models verified correct against backend
- **Stage 03** (`03-service-type-selection.md`) — Service type selection logic verified
- **Stage 04** (`04-wizard-container.md`) — Wizard container verified (error banner already added per Fix C)
- **Stage 08** (`08-signature-step.md`) — CustomerSignatureView 3-binding usage verified correct
- **Stage 09** (`09-confirmation-step.md`) — Uses `BookingDeviceEntry.empty()` which auto-includes accessories
- **Stage 10** (`10-dashboard-integration.md`) — FAB overlay approach verified correct

**Say "Stages 01/03/04/08/09/10: no fixes needed" before proceeding to final checklist.**

---

## Final Verification Checklist

After all fixes are applied, confirm every item:

| # | What | Where |
|---|------|-------|
| 1 | `requiresAddress` checks `serviceType == .buyback \|\| devices.contains...` | Stage 02, `BookingFormData` |
| 2 | `BookingDeviceEntry` has `var accessories: [BookingAccessoryItem]` | Stage 02 |
| 3 | `BookingAccessoryItem` struct exists with `id`, `accessoryType`, `description` | Stage 02 |
| 4 | `BookingDeviceEntry.empty()` initializes `accessories: []` | Stage 02 |
| 5 | `CreateOrderDeviceRequest` has `let accessories: [AccessoryPayload]?` | Stage 02 |
| 6 | `AccessoryPayload` struct exists | Stage 02 |
| 7 | Submit method device loop maps accessories into `AccessoryPayload` array | Stage 02 |
| 8 | No `let sigData` variable anywhere in file | Stage 02 |
| 9 | `CreateOrderRequest.SignatureData` has `signatureMethod: String` | Stage 02 |
| 10 | Submit sends `signatureMethod: formData.signatureType.rawValue` | Stage 02 |
| 11 | Submit sends `typedName` only when `signatureType == .typed` | Stage 02 |
| 12 | Zero occurrences of `AddDeviceRequest` (renamed to `CreateOrderDeviceRequest`) | Stage 02 |
| 13 | Master plan device payload has `passcode`, `passcodeType`, `findMyStatus` | Stage 00 |
| 14 | Master plan signature payload has `signatureMethod` | Stage 00 |
| 15 | Master plan API usage example uses `requestVoid` for devices | Stage 00 |
| 16 | `DeviceEntryFormView` has accessories add/remove section | Stage 06 |
| 17 | `DeviceListItemView` shows accessory count | Stage 06 |
| 18 | All preview `BookingDeviceEntry(...)` literals have `accessories: []` | Stages 06, 07 |
| 19 | `DeviceSummaryCard` shows accessories | Stage 07 |
| 20 | Internal Notes TextField uses `Color(.systemBackground)` | Stage 07 |
| 21 | Stage 05 handoff notes describe `serviceType == .buyback` address behavior | Stage 05 |

**When all 21 items are confirmed, say "All final audit fixes applied and verified."**
