# Stage 03: Summary Step — Line Items Integration

## Objective

Embed the line items UI in each device card on the Summary step. No aftermarket consent here — that moves to the Signature step (Stage 04).

## Dependencies

[Requires: Stage 02 complete] — `DeviceLineItemsList`, `BookingProductSearch`, `TierSelectionSheet` must exist.

## Complexity

Medium

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Repair Minder/Features/Staff/Booking/Steps/SummaryStepView.swift` | Embed `DeviceLineItemsList` in `DeviceSummaryCard` |
| `Repair Minder/Repair Minder/Features/Staff/Booking/BookingViewModel.swift` | No validation changes needed — summary step stays `return true` |

## Implementation Details

### 1. SummaryStepView.swift — DeviceSummaryCard Updates

The `DeviceSummaryCard` currently takes `let device: BookingDeviceEntry`. Change it to accept a binding so line items can be mutated:

```swift
struct DeviceSummaryCard: View {
    @Binding var device: BookingDeviceEntry
    let currencyCode: String

    // ... existing body ...

    // After the accessories section (line ~328), add:

    // Line items
    DeviceLineItemsList(
        items: $device.lineItems,
        currencyCode: currencyCode
    )
}
```

Update the `ForEach` in the devices section to use binding:

```swift
// Before (line ~76):
ForEach(viewModel.formData.devices) { device in
    DeviceSummaryCard(device: device)
}

// After:
ForEach($viewModel.formData.devices) { $device in
    DeviceSummaryCard(device: $device, currencyCode: viewModel.currencyCode)
}
```

### 2. BookingViewModel.swift — No Validation Change

The `.summary` step validation stays as-is (`return true`). Aftermarket consent validation is handled in Stage 04 on the Signature step, matching the web app flow.

### 3. SummaryStepView Preview

Update the `#Preview` to include sample line items:

```swift
// Add to the preview device:
lineItems: [
    BookingLineItem(
        id: UUID(),
        productTypeId: "test",
        description: "Screen Replacement (Aftermarket)",
        quantity: 1,
        unitPrice: 49.99,
        vatRate: 20,
        itemType: "repair",
        qualityTier: "Aftermarket"
    )
],
aftermarketConsent: false
```

## Database Changes

None.

## Test Cases

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Summary step with no line items | "Add Service" button visible, no items listed |
| 2 | Add a service item | Item appears in list with price and remove button |
| 3 | Add aftermarket item | Item appears, no consent checkbox on this step |
| 4 | Add premium-only items | Items appear normally |
| 5 | Remove an item | Item removed, subtotal updates |
| 6 | Can proceed to Signature with or without items | Summary step always valid |
| 7 | iPad layout | Line items render cleanly in wider layout |

## Acceptance Checklist

- [ ] `DeviceSummaryCard` uses binding for device, embeds `DeviceLineItemsList`
- [ ] Line items can be added/removed per device
- [ ] No aftermarket consent checkbox on this step (moved to Stage 04)
- [ ] Summary step validation unchanged (`return true`)
- [ ] Preview updated with sample data
- [ ] All 3 targets build clean

## Deployment

No deployment needed — wiring only. Build verification in Xcode. Commit to git — GitHub Actions handles frontend build on push.

## Handoff Notes

- Stage 04 needs to add the aftermarket consent checkbox to the **Signature step**, not this step
- The `DeviceSummaryCard` now takes a `@Binding` — any code that constructs it needs updating (currently only `SummaryStepView`)
- The `currencyCode` comes from `viewModel.currencyCode` (loaded from company public info)
