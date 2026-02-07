# Prompt: Apply Final Audit Fixes to New Booking Feature Plans

You are editing **plan markdown files** (NOT Swift source files). These plans contain embedded Swift code blocks that will be used later to implement the feature. Apply every fix below exactly as described. Work stage by stage. After each stage, re-read the modified file and confirm the self-check passes before moving on.

> **Important:** The decoder uses `.convertFromSnakeCase` — do NOT add explicit snake_case raw values in CodingKeys unless there's a special case (like `address_line_1` vs `address_line1`).

---

## Stage 02 — `plans/new-booking-feature/02-booking-view-model.md`

6 fixes. Apply in order.

### Fix 1 — CRITICAL: `requiresAddress` must also check `serviceType`

In the `BookingFormData` struct, find:
```swift
    var requiresAddress: Bool {
        devices.contains { $0.workflowType == .buyback }
    }
```

Replace with:
```swift
    var requiresAddress: Bool {
        serviceType == .buyback || devices.contains { $0.workflowType == .buyback }
    }
```

### Fix 2 — CRITICAL: Add `accessories` support

**2a.** In `BookingDeviceEntry`, after `var workflowType: WorkflowType`, add:
```swift
    var accessories: [BookingAccessoryItem]
```

**2b.** Add this new struct immediately after `BookingDeviceEntry`'s closing `}` and before `/// Complete form data for a booking`:
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

**2c.** In `BookingDeviceEntry.empty()`, add `accessories: []` after `workflowType: workflowType`:
```swift
            workflowType: workflowType,
            accessories: []
```

**2d.** In `AddDeviceRequest` (will be renamed in Fix 6), add after `let workflowType: String`:
```swift
    let accessories: [AccessoryPayload]?
```

**2e.** Add this struct immediately after `AddDeviceRequest`'s closing `}` and before `/// Pre-authorisation payload`:
```swift
struct AccessoryPayload: Encodable {
    let accessoryType: String
    let description: String
}
```

**2f.** In the `submit()` method's device loop, find where the device request is constructed. After `workflowType: device.workflowType.rawValue`, add:
```swift
                    accessories: device.accessories.isEmpty ? nil : device.accessories.map {
                        AccessoryPayload(accessoryType: $0.accessoryType, description: $0.description)
                    }
```

### Fix 3 — MAJOR: Remove dead `sigData` variable

In `submit()`, find and DELETE these 3 lines:
```swift
            // 3. Compute signature data from CustomerSignatureView bindings
            // formData.signatureData is a computed property that returns base64 data URL or typed name
            let sigData = formData.signatureData
```

Then rename the next comment from `// 3b.` to `// 3.`:
```
            // 3b. Build pre-authorization if enabled
```
becomes:
```
            // 3. Build pre-authorization if enabled
```

### Fix 4 — MAJOR: Add `signatureMethod` to `SignatureData`

Find:
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

Replace with:
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

### Fix 5 — MAJOR: Fix signature mutual exclusivity + wire `signatureMethod`

In `submit()`, find:
```swift
                signature: CreateOrderRequest.SignatureData(
                    signatureData: formData.signatureType == .drawn ? formData.signatureData : nil,
                    typedName: formData.typedName.isEmpty ? nil : formData.typedName,
                    termsAgreed: formData.termsAgreed,
```

Replace with:
```swift
                signature: CreateOrderRequest.SignatureData(
                    signatureData: formData.signatureType == .drawn ? formData.signatureData : nil,
                    typedName: formData.signatureType == .typed && !formData.typedName.isEmpty ? formData.typedName : nil,
                    signatureMethod: formData.signatureType.rawValue,
                    termsAgreed: formData.termsAgreed,
```

### Fix 6 — MINOR: Rename `AddDeviceRequest` → `CreateOrderDeviceRequest`

Find every occurrence of `AddDeviceRequest` in the file and rename to `CreateOrderDeviceRequest`. There should be 2:
1. `struct AddDeviceRequest: Encodable {`
2. `let deviceRequest = AddDeviceRequest(`

### Stage 02 Self-Check

Re-read the file. Confirm:
1. `requiresAddress` contains `serviceType == .buyback`
2. `BookingDeviceEntry` has `var accessories: [BookingAccessoryItem]`
3. `BookingAccessoryItem` struct exists with `id`, `accessoryType`, `description`
4. `BookingDeviceEntry.empty()` includes `accessories: []`
5. `CreateOrderDeviceRequest` has `let accessories: [AccessoryPayload]?`
6. `AccessoryPayload` struct exists
7. No `let sigData` line exists anywhere
8. `SignatureData` has 7 fields including `signatureMethod`
9. Submit sends `signatureMethod: formData.signatureType.rawValue`
10. Submit sends `typedName` only when `signatureType == .typed`
11. Zero occurrences of `AddDeviceRequest` remain
12. Device loop in submit includes `accessories:` mapping

---

## Stage 00 — `plans/new-booking-feature/00-master-plan.md`

3 fixes.

### Fix 7 — Update device payload with missing fields

Find the `CreateOrderDeviceRequest` struct in the "Add Device Payload" section (around line 246) and replace the **entire struct block** (both `CreateOrderDeviceRequest` and `AccessoryItem`) with:

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

### Fix 8 — Add `signatureMethod` to `SignaturePayload`

Find the `SignaturePayload` struct in the "Order Creation Payload" section. Add after the `let typedName: String?` line:
```swift
    let signatureMethod: String       // "drawn" or "typed"
```

### Fix 9 — Use `requestVoid` for device addition

Find in the "API Client Usage Patterns" section:
```swift
// POST device to order
let device: OrderDevice = try await APIClient.shared.request(
    .createOrderDevice(orderId: orderId),
    body: deviceRequest
)
```

Replace with:
```swift
// POST device to order (returns { id } but we don't need it)
try await APIClient.shared.requestVoid(
    .createOrderDevice(orderId: orderId),
    body: deviceRequest
)
```

### Stage 00 Self-Check

Re-read the file. Confirm:
1. `CreateOrderDeviceRequest` has `passcode`, `passcodeType`, `findMyStatus`
2. `SignaturePayload` has `signatureMethod` field
3. API usage example uses `requestVoid` for device addition
4. `AccessoryItem` struct exists

---

## Stage 06 — `plans/new-booking-feature/06-devices-step.md`

3 fixes.

### Fix 10 — Add accessories section to `DeviceEntryFormView`

In `DeviceEntryFormView`, find the Workflow Type section (the `if viewModel.formData.serviceType == .repair {` block). **After its closing `}`** and **before** the `// Save Button` comment, add this new section:

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

### Fix 11 — Show accessory count in `DeviceListItemView`

In `DeviceListItemView`, find the block that shows `customerReportedIssues`. After its closing `}`, add:

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

### Fix 12 — Update preview `BookingDeviceEntry(...)` literals

Find the `BookingDeviceEntry(...)` literal in the `DeviceListItemView` `#Preview`. Add `accessories: []` as the last parameter after `workflowType: .repair`:

```swift
                workflowType: .repair,
                accessories: []
```

### Stage 06 Self-Check

Re-read the file. Confirm:
1. `DeviceEntryFormView` has "Accessories Included" section
2. `DeviceListItemView` shows accessory count
3. All `BookingDeviceEntry(...)` preview literals include `accessories: []`

---

## Stage 07 — `plans/new-booking-feature/07-summary-step.md`

3 fixes.

### Fix 13 — Show accessories in `DeviceSummaryCard`

In `DeviceSummaryCard`, find the `HStack` that shows condition/findMy/passcode labels (the one with `Label(device.conditionGrade.displayName, systemImage: "star")`). After that `HStack`'s closing `}`, add:

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

### Fix 14 — Fix double background on Internal Notes

Find the Internal Notes `TextField`:
```swift
                TextField("e.g. Customer mentioned they need it back by Friday", text: $viewModel.formData.internalNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color(.systemGray6))
```

Change `.background(Color(.systemGray6))` to:
```swift
                    .background(Color(.systemBackground))
```

### Fix 15 — Update preview `BookingDeviceEntry(...)` literal

Find the `BookingDeviceEntry(...)` literal in the `#Preview` at the bottom. Add `accessories: []` after `workflowType: .repair`:

```swift
                    workflowType: .repair,
                    accessories: []
```

### Stage 07 Self-Check

Re-read the file. Confirm:
1. `DeviceSummaryCard` shows accessories line
2. Internal Notes TextField uses `Color(.systemBackground)` not `Color(.systemGray6)`
3. Preview `BookingDeviceEntry(...)` has `accessories: []`

---

## Stage 05 — `plans/new-booking-feature/05-client-step.md`

1 fix.

### Fix 16 — Update handoff notes about `requiresAddress`

Find in the Handoff Notes section:
```
- [See: Stage 06] Devices step may trigger address requirement for buyback
```

Replace with:
```
- Address section shows automatically for buyback service type (`requiresAddress` checks `serviceType == .buyback`)
- Address also shows if any individual device has `workflowType == .buyback` (for mixed repair+buyback orders)
- [See: Stage 06] Adding buyback devices on a repair order also triggers address requirement
```

### Stage 05 Self-Check

Confirm the handoff notes mention `serviceType == .buyback` triggering address.

---

## Stages with NO fixes needed

Confirm these are unchanged:
- **Stage 01** (`01-models-and-api-endpoints.md`) — No fixes
- **Stage 03** (`03-service-type-selection.md`) — No fixes
- **Stage 04** (`04-wizard-container.md`) — No fixes
- **Stage 08** (`08-signature-step.md`) — No fixes
- **Stage 09** (`09-confirmation-step.md`) — No fixes
- **Stage 10** (`10-dashboard-integration.md`) — No fixes

---

## Final Verification (all 21 items)

| # | What | File |
|---|------|------|
| 1 | `requiresAddress` checks `serviceType == .buyback \|\| devices.contains...` | Stage 02 |
| 2 | `BookingDeviceEntry` has `var accessories: [BookingAccessoryItem]` | Stage 02 |
| 3 | `BookingAccessoryItem` struct exists with `id`, `accessoryType`, `description` | Stage 02 |
| 4 | `BookingDeviceEntry.empty()` initializes `accessories: []` | Stage 02 |
| 5 | `CreateOrderDeviceRequest` has `let accessories: [AccessoryPayload]?` | Stage 02 |
| 6 | `AccessoryPayload` struct exists | Stage 02 |
| 7 | Submit device loop maps accessories into `AccessoryPayload` array | Stage 02 |
| 8 | No `let sigData` variable anywhere | Stage 02 |
| 9 | `SignatureData` has `signatureMethod: String` | Stage 02 |
| 10 | Submit sends `signatureMethod: formData.signatureType.rawValue` | Stage 02 |
| 11 | Submit sends `typedName` only when `signatureType == .typed` | Stage 02 |
| 12 | Zero occurrences of `AddDeviceRequest` | Stage 02 |
| 13 | Master plan device payload has `passcode`, `passcodeType`, `findMyStatus` | Stage 00 |
| 14 | Master plan signature payload has `signatureMethod` | Stage 00 |
| 15 | Master plan API usage uses `requestVoid` for devices | Stage 00 |
| 16 | `DeviceEntryFormView` has accessories add/remove section | Stage 06 |
| 17 | `DeviceListItemView` shows accessory count | Stage 06 |
| 18 | All preview `BookingDeviceEntry(...)` literals have `accessories: []` | Stages 06, 07 |
| 19 | `DeviceSummaryCard` shows accessories | Stage 07 |
| 20 | Internal Notes TextField uses `Color(.systemBackground)` | Stage 07 |
| 21 | Stage 05 handoff notes describe `serviceType == .buyback` address behavior | Stage 05 |

When all 21 items pass, say **"All final audit fixes applied and verified."**
