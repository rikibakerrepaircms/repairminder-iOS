# Stage 04: Signature Step — Aftermarket Consent + Submission Wiring

## Objective

Add aftermarket consent checkboxes and "Planned Services" summary to the Signature step. Update the submission flow to capture device IDs and create line items via the existing API. The consent checkbox lives here (not on Summary), matching the web app flow.

## Dependencies

[Requires: Stage 03 complete] — Line items are captured on the Summary step.

## Complexity

Medium-High (submission flow is the most critical change in this project)

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Repair Minder/Features/Staff/Booking/Steps/SummaryStepView.swift` | **Remove** `AftermarketConsentToggle` and its usage from `DeviceSummaryCard` (moved to Signature step) |
| `Repair Minder/Repair Minder/Features/Staff/Booking/Steps/SignatureStepView.swift` | Add "Planned Services" section, aftermarket consent checkboxes per device |
| `Repair Minder/Repair Minder/Features/Staff/Booking/BookingViewModel.swift` | Move aftermarket validation from `.summary` → `.signature`, add `DeviceCreateResponse`, switch `requestVoid` → `request`, add line item creation loop |

## Implementation Details

### 0. Move Consent from Summary → Signature (REQUIRED FIRST)

Stage 03 placed the aftermarket consent checkbox on the Summary step. This stage moves it to the Signature step to match the web app.

**In `SummaryStepView.swift`:**
- Remove the `AftermarketConsentToggle` usage from `DeviceSummaryCard` (lines ~341-346: the `if device.hasAftermarketItems { ... }` block)
- Delete the `AftermarketConsentToggle` struct entirely (lines ~362-400) — it will be rebuilt inline in SignatureStepView
- Keep `DeviceLineItemsList` in `DeviceSummaryCard` (that stays on Summary)

**In `BookingViewModel.swift`:**
- Change `isCurrentStepValid` for `.summary` from `return formData.allAftermarketConsented` back to `return true`
- Add the aftermarket check to `.signature` instead (see section 3 below)

### 1. SignatureStepView.swift — Planned Services + Aftermarket Consent

Add before the terms agreement section (before line 26), only when any device has line items:

```swift
// Planned Services Summary (only if any device has line items)
let devicesWithItems = viewModel.formData.devices.filter { !$0.lineItems.isEmpty }

if !devicesWithItems.isEmpty {
    VStack(alignment: .leading, spacing: 12) {
        Text("Planned Services")
            .font(.headline)

        ForEach(devicesWithItems) { device in
            VStack(alignment: .leading, spacing: 6) {
                Text(device.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                ForEach(device.lineItems) { item in
                    HStack {
                        Text("• \(item.description)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyFormatter.format(item.unitPrice))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 8)
                }

                // Subtotal per device
                HStack {
                    Spacer()
                    Text("Device subtotal:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(device.lineItemSubtotal))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.leading, 8)
            }
            .padding()
            .background(Color.platformGray6)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
```

### 2. SignatureStepView.swift — Aftermarket Consent Checkboxes

Add after the "Planned Services" section, before the terms agreement. One checkbox per device that has aftermarket items:

```swift
// Aftermarket consent (per device with aftermarket items)
let aftermarketDeviceIndices = viewModel.formData.devices.indices.filter { i in
    viewModel.formData.devices[i].hasAftermarketItems
}

if !aftermarketDeviceIndices.isEmpty {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(aftermarketDeviceIndices, id: \.self) { index in
            let device = viewModel.formData.devices[index]

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Toggle("", isOn: $viewModel.formData.devices[index].aftermarketConsent)
                        .labelsHidden()
                        .tint(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aftermarket Parts — \(device.displayName)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("This repair uses an aftermarket display not designed or manufactured by Apple. It may not perform identically to an original component.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Customer acknowledges and agrees to the use of aftermarket parts for this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !device.aftermarketConsent {
                    Label("Customer must acknowledge aftermarket parts to proceed.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
```

### 3. BookingViewModel.swift — Validation

Update `isCurrentStepValid` for the `.signature` case to also require aftermarket consent:

```swift
case .signature:
    guard formData.hasValidSignature else { return false }
    return formData.allAftermarketConsented
```

This means:
- If no devices have aftermarket items → `allAftermarketConsented` returns `true` → only signature needed
- If any device has aftermarket items without consent → returns `false` → "Submit" button is disabled

### 4. BookingViewModel.swift — Response Type

Add a response type for device creation (backend returns `{ data: { id: "<device-id>" } }`):

```swift
/// Response from POST /api/orders/:orderId/devices
/// APIClient unwraps the `data` envelope, so we decode the inner object.
struct DeviceCreateResponse: Decodable {
    let id: String
}
```

### 5. BookingViewModel.swift — submit() Changes

This is the critical change. Currently (lines 396-425):

```swift
// 7. Add each device
for device in formData.devices {
    let deviceRequest = CreateOrderDeviceRequest(...)
    try await APIClient.shared.requestVoid(
        .createOrderDevice(orderId: orderId),
        body: deviceRequest
    )
}
```

Replace with:

```swift
// 7. Add each device and capture IDs for line item creation
var deviceIdMap: [(device: BookingDeviceEntry, apiId: String)] = []

for device in formData.devices {
    let deviceRequest = CreateOrderDeviceRequest(
        brandId: device.brandId,
        modelId: device.modelId,
        customBrand: device.customBrand,
        customModel: device.customModel,
        serialNumber: device.serialNumber.isEmpty ? nil : device.serialNumber,
        imei: device.imei.isEmpty ? nil : device.imei,
        colour: device.colour.isEmpty ? nil : device.colour,
        storageCapacity: device.storageCapacity.isEmpty ? nil : device.storageCapacity,
        passcode: device.passcode.isEmpty ? nil : device.passcode,
        passcodeType: device.passcodeType == .none ? nil : device.passcodeType.rawValue,
        findMyStatus: device.findMyStatus.rawValue,
        conditionGrade: device.conditionGrade.rawValue,
        customerReportedIssues: device.customerReportedIssues.isEmpty ? nil : device.customerReportedIssues,
        deviceTypeId: device.deviceTypeId,
        workflowType: device.workflowType.rawValue,
        accessories: device.accessories.isEmpty ? nil : device.accessories.map {
            AccessoryPayload(accessoryType: $0.accessoryType, description: $0.description)
        },
        aftermarketConsent: device.aftermarketConsent ? 1 : 0
    )

    let response: DeviceCreateResponse = try await APIClient.shared.request(
        .createOrderDevice(orderId: orderId),
        body: deviceRequest
    )
    deviceIdMap.append((device: device, apiId: response.id))
}

// 8. Create line items per device (best-effort — order still valid if items fail)
for (device, apiDeviceId) in deviceIdMap {
    for item in device.lineItems {
        do {
            let netPrice = item.unitPrice / (1 + item.vatRate / 100)
            let itemRequest = OrderItemRequest(
                itemType: item.itemType,
                description: item.description,
                quantity: item.quantity,
                unitPrice: netPrice,
                priceIncVat: item.unitPrice,
                vatRate: item.vatRate,
                deviceId: apiDeviceId,
                isWarrantyItem: nil,
                warrantyNotes: nil,
                productTypeId: item.productTypeId,
                qualityTier: item.qualityTier.isEmpty ? nil : item.qualityTier
            )
            try await APIClient.shared.requestVoid(
                .createOrderItem(orderId: orderId),
                body: itemRequest
            )
        } catch {
            // Non-fatal — log and continue. Staff can add items from Order Detail.
            logger.error("Failed to create line item '\(item.description)' for device \(apiDeviceId): \(error)")
        }
    }
}
```

**Key changes:**
1. `requestVoid` → `request<DeviceCreateResponse>` to capture device IDs
2. Added `aftermarketConsent: device.aftermarketConsent ? 1 : 0` to the device request
3. New loop creates line items per device via existing `.createOrderItem(orderId:)` endpoint
4. `unitPrice` is converted from inc-VAT to net (backend expects net price in `unitPrice`)
5. Line item creation is wrapped in do/catch per item — failure is non-fatal

### 6. Renumber Subsequent Steps

The existing code has `// 8. Update form data with results`. Renumber to:

```swift
// 9. Update form data with results
formData.createdOrderId = orderId
formData.createdOrderNumber = orderNumber
formData.createdTicketId = orderResponse.ticketId

// 10. Move to confirmation
currentStep = .confirmation
```

## Database Changes

None — all backend fields and endpoints already exist.

## Test Cases

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Booking with no line items | Same as before — no items created, consent defaults to 0 |
| 2 | Booking with 1 device, 2 items | Order created, device created (with consent flag), 2 items created |
| 3 | Booking with aftermarket items + consent | `aftermarket_consent = 1` on the device in the database |
| 4 | Booking with 2 devices, items on both | Each device gets its own items (correct device_id) |
| 5 | Line item creation fails (network error) | Order + device still created, error logged, user sees confirmation |
| 6 | Signature step shows planned services | Each device with items shown with descriptions and prices |
| 7 | Aftermarket consent checkbox on Signature step | Amber checkbox per device with aftermarket items |
| 8 | Try to submit without aftermarket consent | Submit button disabled |
| 9 | Consent given + terms agreed + signature | Submit succeeds |
| 10 | Signature step with no aftermarket items | No consent checkboxes shown, only terms + signature needed |
| 11 | Verify backend receives quality_tier | Check order items in web dashboard — tier should appear |
| 12 | Verify backend receives aftermarket_consent | Check device in web dashboard — aftermarket badge should appear |

## Acceptance Checklist

- [ ] `DeviceCreateResponse` struct added to BookingViewModel.swift
- [ ] `submit()` captures device IDs via `request<DeviceCreateResponse>`
- [ ] `submit()` sends `aftermarketConsent` in device request
- [ ] `submit()` creates line items per device with correct device_id
- [ ] `submit()` converts unitPrice from inc-VAT to net for backend
- [ ] `submit()` sends `qualityTier` in item request
- [ ] Line item creation is best-effort (non-fatal errors)
- [ ] SignatureStepView shows "Planned Services" when items exist
- [ ] SignatureStepView shows aftermarket consent checkboxes per device
- [ ] `isCurrentStepValid` for `.signature` requires `allAftermarketConsented`
- [ ] Cannot submit without aftermarket consent when applicable
- [ ] End-to-end test: create booking on iOS, verify in web dashboard
- [ ] All 3 targets build clean
- [ ] Committed to git

## Deployment

No worker deploy needed (backend unchanged). Commit to git — GitHub Actions handles frontend build on push.

Test on simulator or device:

1. Create a booking with a service product that has aftermarket tier
2. On the Summary step, add the service — no consent checkbox here
3. Proceed to Signature step — aftermarket consent checkbox appears
4. Toggle consent, agree to terms, sign, submit
5. Open the order in the web dashboard
6. Verify: items appear on the order, aftermarket consent flag is set, quality_tier is correct

## Handoff Notes

- This is the most critical stage — the submission flow change affects all bookings, not just aftermarket ones
- The `requestVoid` → `request<DeviceCreateResponse>` switch should be backward-compatible (the backend always returned the device ID, the iOS app just wasn't reading it)
- Stage 05 (Customer Portal) is independent and may already be complete if it ran in parallel with Stages 2-4
- After this stage, the full booking-to-receipt-to-invoice flow works end-to-end across web + iOS
- The web app's consent checkbox was also moved from Summary → Signature to match this flow
