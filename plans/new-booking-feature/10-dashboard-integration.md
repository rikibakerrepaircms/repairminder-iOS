# Stage 10: Dashboard Integration

## Objective

Wire up the "New Booking" button on the dashboard to launch the booking wizard, and add necessary navigation routes.

## Dependencies

`[Requires: Stage 03 complete]` - Needs BookingView
`[Requires: Stage 04-09 complete]` - Needs complete wizard flow

## Complexity

**Low** - Simple wiring of existing components.

---

## Files to Modify

| File | Changes |
|------|---------|
| `Features/Dashboard/Components/QuickActionsView.swift` | Change "New Order" to "New Booking", launch BookingView |
| `App/AppRouter.swift` | Add booking route (optional, if using navigation) |

---

## Implementation Details

### QuickActionsView.swift (Modified)

Replace the existing file with updated booking functionality:

```swift
//
//  QuickActionsView.swift
//  Repair Minder
//

import SwiftUI

struct QuickActionsView: View {
    @Environment(AppRouter.self) private var router
    @State private var showBookingSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "New Booking",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    showBookingSheet = true
                }

                QuickActionButton(
                    title: "Scan",
                    icon: "qrcode.viewfinder",
                    color: .green
                ) {
                    router.navigate(to: .scanner)
                }

                QuickActionButton(
                    title: "Devices",
                    icon: "iphone",
                    color: .orange
                ) {
                    router.navigate(to: .devices)
                }
            }
        }
        .fullScreenCover(isPresented: $showBookingSheet) {
            BookingView()
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickActionsView()
        .environment(AppRouter())
        .padding()
}
```

### AppRouter.swift (Optional Addition)

If you want to support deep linking to booking, add a route:

```swift
// In AppRoute enum, add:
case booking

// In routeDestination(for:) function in DashboardView, add:
case .booking:
    BookingView()
```

---

## Alternative: Sheet vs Navigation

**Option A: Full Screen Cover (Recommended)**
- Uses `.fullScreenCover` for modal presentation
- Booking wizard takes full screen
- Dismiss returns to dashboard

**Option B: Navigation Push**
- Uses navigation stack
- Adds booking as a route
- Back button returns to dashboard

The implementation above uses **Option A** which matches the web app behavior.

---

## Database Changes

**None**

---

## Test Cases

### Test 1: Button Label
- Dashboard shows "New Booking" (not "New Order")
- Button has blue plus icon

### Test 2: Launch Booking
- Tap "New Booking" button
- Full screen booking view appears
- Service type selection visible

### Test 3: Complete Flow
- Select "Repair"
- Complete all wizard steps
- Submit booking
- See confirmation
- Tap "Done"
- Returns to dashboard

### Test 4: Cancel Flow
- Launch booking
- Tap X to cancel
- Returns to dashboard
- No data persisted

### Test 5: Other Buttons Unaffected
- "Scan" still navigates to scanner
- "Devices" still navigates to devices list

---

## Acceptance Checklist

- [ ] "New Order" button renamed to "New Booking"
- [ ] Button launches `BookingView` as full screen cover
- [ ] Complete booking flow works from dashboard
- [ ] Cancel returns to dashboard
- [ ] Done returns to dashboard
- [ ] Other quick action buttons still work
- [ ] Preview renders without error
- [ ] Project compiles without errors

---

## Deployment

```bash
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Full Build and Test

```bash
# Clean build
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild clean -scheme "Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run on simulator
# 1. Open Xcode
# 2. Select "Repair Minder" scheme
# 3. Select iPhone 17 Pro simulator
# 4. Run (Cmd+R)
```

### Manual Testing Checklist

1. ✓ App launches
2. ✓ Login successfully
3. ✓ Dashboard loads
4. ✓ Tap "New Booking"
5. ✓ Service type selection appears
6. ✓ Select "Repair"
7. ✓ Enter customer info
8. ✓ Continue to devices
9. ✓ Add a device
10. ✓ Continue to summary
11. ✓ Continue to signature
12. ✓ Agree to terms
13. ✓ Sign or type name
14. ✓ Tap "Complete Booking"
15. ✓ See confirmation with order number
16. ✓ Tap "Done"
17. ✓ Returns to dashboard

---

## Handoff Notes

- This completes the New Booking feature
- All stages are now complete
- Feature is accessible from dashboard
- Future enhancements:
  - Ticket linking (link enquiry to order)
  - Sub-location assignment
  - Engineer assignment
  - Accessories wizard implementation
