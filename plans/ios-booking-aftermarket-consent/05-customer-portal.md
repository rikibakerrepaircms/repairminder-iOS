# Stage 05: Customer Portal + Staff Display

## Objective

Add aftermarket consent display to the customer portal device card and optionally to the staff order detail.

## Dependencies

[Requires: Stage 01 complete] — Only needs the model pattern, not the UI stages. **Can run in parallel with Stages 02–04.**

## Complexity

Low

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Repair Minder/Core/Models/CustomerDevice.swift` | Add `aftermarketConsent: Int?` with decoding |
| `Repair Minder/Repair Minder/Features/Customer/Components/CustomerDeviceCard.swift` | Add amber notice when aftermarket consent is set |

## Implementation Details

### 1. CustomerDevice.swift — Add Field

The backend already returns `aftermarket_consent` (integer 0 or 1) on customer device responses. Add it to the model.

**Add property:**

```swift
let aftermarketConsent: Int?
```

**Add to CodingKeys enum (line ~58):**

```swift
case aftermarketConsent
```

**Add to `init(from:)` (after line ~104, before images):**

```swift
aftermarketConsent = try container.decodeIfPresent(Int.self, forKey: .aftermarketConsent)
```

**Add computed helper:**

```swift
/// Whether the customer acknowledged aftermarket parts
var hasAftermarketConsent: Bool {
    aftermarketConsent == 1
}
```

### 2. CustomerDeviceCard.swift — Amber Notice

Read the file to find the right insertion point. Add an amber notice banner after the device header section, before the progress bar or authorization section.

```swift
// Aftermarket parts notice
if device.hasAftermarketConsent {
    HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
            .font(.caption)

        VStack(alignment: .leading, spacing: 2) {
            Text("Aftermarket Parts")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.orange)
            Text("This device uses aftermarket components. Acknowledged at booking.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.orange.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

### 3. Staff Order Detail (Optional)

The `OrderDeviceSummary` model (in `Order.swift`) can optionally receive `aftermarketConsent` too. This was added in Stage 01. If the staff order detail view shows device cards, a small "Aftermarket" badge can be added:

```swift
if device.aftermarketConsent == 1 {
    Text("Aftermarket")
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(.orange)
        .clipShape(Capsule())
}
```

This is a nice-to-have. The primary goal is the customer portal notice.

## Database Changes

None.

## Test Cases

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Customer portal — device with aftermarket_consent = 1 | Amber notice visible |
| 2 | Customer portal — device with aftermarket_consent = 0 | No notice |
| 3 | Customer portal — device with aftermarket_consent = null | No notice (decodes as nil, `hasAftermarketConsent` returns false) |
| 4 | Customer portal — 2 devices, one aftermarket | Notice only on the aftermarket device |
| 5 | Build all 3 targets | Compiles without errors |
| 6 | Existing customer portal unchanged for non-aftermarket orders | No visual changes |

## Acceptance Checklist

- [ ] `CustomerDevice` has `aftermarketConsent: Int?` property
- [ ] `aftermarketConsent` added to CodingKeys and `init(from:)`
- [ ] `hasAftermarketConsent` computed property added
- [ ] `CustomerDeviceCard` shows amber notice when `hasAftermarketConsent` is true
- [ ] No notice shown for devices without aftermarket consent
- [ ] All 3 targets build clean

## Deployment

No deployment needed — model and UI changes only.

To verify end-to-end:
1. Create an order with aftermarket consent via the web dashboard or iOS booking
2. Open the customer portal (on iOS simulator or device)
3. Navigate to the order → device card should show the amber notice

## Handoff Notes

- This is the final stage. After completion, the full feature set is:
  - Staff can add line items per device during booking (iOS/iPad/Mac)
  - Aftermarket consent is captured per device
  - Consent surfaces on booking receipt + invoice (backend-generated, already live)
  - Customer portal shows aftermarket notice
- Future enhancements (not in this plan):
  - Company-configurable consent wording
  - Mail-in booking support
  - Pre-auth auto-calculation from line item totals
