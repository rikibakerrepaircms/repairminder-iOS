# Stage 10: FAB Integration

## Objective

Add a branded blue floating action button (FAB) to StaffMainView that launches the booking wizard as a full-screen modal. The FAB appears on ALL staff tabs as an overlay.

## Dependencies

`[Requires: Stage 03 complete]` - Needs BookingView
`[Requires: Stage 04-09 complete]` - Needs complete wizard flow

## Complexity

**Low** - Simple overlay + fullScreenCover addition.

---

## Files to Modify

| File | Changes |
|------|---------|
| `Repair_MinderApp.swift` | Add FAB overlay and fullScreenCover to StaffMainView |

---

## Implementation Details

### StaffMainView (Modified in Repair_MinderApp.swift)

> **IMPORTANT — DO NOT WRAP TabView IN NavigationStack.**
> Individual tabs already have their own NavigationStacks (e.g. Orders tab, Enquiries tab).
> Adding an outer NavigationStack would create double navigation bars on those tabs.
> Instead, use `.overlay` for the FAB and `.fullScreenCover` directly on the TabView.
> See Test 7 below to verify this.

Add a `@State private var showBookingSheet = false` and apply the FAB as an overlay:

> **WARNING:** The code below shows ONLY the new additions (`showBookingSheet`, `.overlay`, `.fullScreenCover`).
> Do NOT replace the existing StaffMainView — it has additional properties including
> `deepLinkHandler`, `deepLinkOrderId`, `deepLinkEnquiryId`, `deepLinkDeviceId`, and various
> `.onChange` and `.onAppear` modifiers that MUST be preserved. Only ADD the new code.

```swift
/// Main staff interface with tab navigation
private struct StaffMainView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var selectedTab: StaffTab = .dashboard
    @State private var showBookingSheet = false

    // ... existing deepLinkOrderId, deepLinkEnquiryId, deepLinkDeviceId etc.

    var body: some View {
        TabView(selection: $selectedTab) {
            // ... existing tabs (dashboard, queue, orders, enquiries, more)
            // KEEP ALL EXISTING TAB CODE AS-IS
        }
        // ... existing modifiers (.onChange, .onAppear, etc.)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showBookingSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 90) // Above tab bar — accounts for 49pt tab bar + safe area on all current iPhones
        }
        .fullScreenCover(isPresented: $showBookingSheet) {
            BookingView()
        }
    }
}
```

### Key Changes

1. **Add `@State private var showBookingSheet`** - Controls modal presentation
2. **Add `.overlay(alignment: .bottomTrailing)`** - Branded blue FAB, positioned above the tab bar in the bottom-right corner
3. **Add `.fullScreenCover`** - Presents BookingView as full-screen modal
4. **NO NavigationStack wrapper** - The TabView is NOT wrapped in NavigationStack (individual tabs handle their own navigation)

### FAB Design Specs

- **Size:** 56×56 points
- **Color:** Blue (`.blue`) matching app brand
- **Icon:** SF Symbol `plus` in white
- **Shape:** Circle
- **Shadow:** Blue-tinted, radius 8
- **Position:** Bottom-right, 20pt from trailing edge, 90pt from bottom (above tab bar)
- **Visible on ALL tabs** — since it's an overlay on the TabView itself
- **Hidden during booking** — the `.fullScreenCover` naturally covers the FAB, so no extra hide logic is needed

> **Note:** The `.padding(.bottom, 90)` value is tuned for the default tab bar height (~49pt + safe area). If the tab bar height changes or on devices with unusual safe areas, this may need adjustment. 90pt is a reliable default across current iPhone models.

---

## Database Changes

**None**

---

## Test Cases

### Test 1: FAB Appearance
- Blue circular FAB visible in bottom right of screen
- FAB is above the tab bar
- FAB appears on all staff tabs

### Test 2: FAB Across Tabs
- Switch between Dashboard, My Queue, Orders, Enquiries, More tabs
- FAB remains visible on every tab

### Test 3: Launch Booking
- Tap blue FAB
- Full screen booking view appears
- Service type selection visible

### Test 4: Complete Flow
- Select "Repair"
- Complete all wizard steps
- Submit booking
- See confirmation
- Tap "Done"
- Returns to staff view (same tab as before)

### Test 5: Cancel Flow
- Launch booking via FAB
- Tap X to cancel
- Returns to staff view
- No data persisted

### Test 6: Tab Preservation
- Be on "Orders" tab
- Tap FAB, complete booking
- After dismissing, still on "Orders" tab

### Test 7: No Double Navigation Bars
- Verify no double navigation bars appear on any tab
- Each tab shows only its own navigation bar

---

## Acceptance Checklist

- [ ] Blue circular FAB visible in bottom right as overlay
- [ ] FAB appears across all staff tabs
- [ ] FAB positioned above tab bar
- [ ] Tapping FAB launches `BookingView` as full screen cover
- [ ] TabView is NOT wrapped in NavigationStack (no double nav bars)
- [ ] Complete booking flow works
- [ ] Cancel returns to previous screen
- [ ] Done returns to previous screen
- [ ] Tab selection is preserved after dismissing booking
- [ ] Project compiles without errors

---

## Deployment

```bash
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Manual Testing Checklist

1. App launches
2. Login successfully
3. Staff view loads with tabs
4. Blue FAB visible in bottom right
5. Switch tabs — FAB remains visible
6. Tap FAB
7. Booking view appears full screen
8. Select "Repair"
9. Enter customer info
10. Continue to devices
11. Add a device
12. Continue to summary
13. Continue to signature
14. Agree to terms
15. Sign or type name
16. Tap "Complete Booking"
17. See confirmation with order number
18. Tap "Done"
19. Returns to staff view on same tab

---

## Handoff Notes

- This completes the New Booking feature
- All stages are now complete
- Feature accessible via branded blue FAB overlay on all tabs
- FAB uses `.overlay(alignment: .bottomTrailing)` — no NavigationStack wrapping
- Future enhancements:
  - Sub-location assignment
  - Engineer assignment
  - Accessories wizard implementation
