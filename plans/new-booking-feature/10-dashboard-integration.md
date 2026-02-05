# Stage 10: Toolbar Integration

## Objective

Add a blue plus icon to the StaffMainView toolbar (top right) that launches the booking wizard as a full-screen modal.

## Dependencies

`[Requires: Stage 03 complete]` - Needs BookingView
`[Requires: Stage 04-09 complete]` - Needs complete wizard flow

## Complexity

**Low** - Simple toolbar button addition.

---

## Files to Modify

| File | Changes |
|------|---------|
| `Repair_MinderApp.swift` | Add toolbar to StaffMainView with blue plus button |

---

## Implementation Details

### StaffMainView (Modified in Repair_MinderApp.swift)

Update the `StaffMainView` struct to add a toolbar with the booking button:

```swift
/// Main staff interface with tab navigation
private struct StaffMainView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var selectedTab: StaffTab = .dashboard
    @State private var showBookingSheet = false

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.fill")
                    }
                    .tag(StaffTab.dashboard)

                MyQueueView()
                    .tabItem {
                        Label("My Queue", systemImage: "tray.full.fill")
                    }
                    .tag(StaffTab.queue)

                OrderListView()
                    .tabItem {
                        Label("Orders", systemImage: "doc.text.fill")
                    }
                    .tag(StaffTab.orders)

                EnquiryListView()
                    .tabItem {
                        Label("Enquiries", systemImage: "envelope.fill")
                    }
                    .tag(StaffTab.enquiries)

                SettingsView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle.fill")
                    }
                    .tag(StaffTab.more)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBookingSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .fullScreenCover(isPresented: $showBookingSheet) {
                BookingView()
            }
        }
    }
}
```

### Key Changes

1. **Wrap TabView in NavigationStack** - Required for toolbar to appear
2. **Add `@State private var showBookingSheet`** - Controls modal presentation
3. **Add `.toolbar` modifier** - Places blue plus icon in top right
4. **Add `.fullScreenCover`** - Presents BookingView as full-screen modal

---

## Alternative Placement Options

If you want the plus button to appear on specific tabs only, you could add the toolbar to individual views instead:

```swift
// In DashboardView.swift
struct DashboardView: View {
    @State private var showBookingSheet = false

    var body: some View {
        ScrollView {
            // ... dashboard content
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showBookingSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
        }
        .fullScreenCover(isPresented: $showBookingSheet) {
            BookingView()
        }
    }
}
```

The recommended approach (in StaffMainView) makes the button always visible across all tabs.

---

## Database Changes

**None**

---

## Test Cases

### Test 1: Button Appearance
- Plus icon visible in top right of screen
- Icon is blue colored
- Icon appears on all staff tabs

### Test 2: Launch Booking
- Tap blue plus icon
- Full screen booking view appears
- Service type selection visible

### Test 3: Complete Flow
- Select "Repair"
- Complete all wizard steps
- Submit booking
- See confirmation
- Tap "Done"
- Returns to staff view (same tab as before)

### Test 4: Cancel Flow
- Launch booking
- Tap X to cancel
- Returns to staff view
- No data persisted

### Test 5: Tab Preservation
- Be on "Orders" tab
- Tap plus icon, complete booking
- After dismissing, still on "Orders" tab

---

## Acceptance Checklist

- [ ] Blue plus icon visible in top right toolbar
- [ ] Icon appears across all staff tabs
- [ ] Tapping icon launches `BookingView` as full screen cover
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

1. ✓ App launches
2. ✓ Login successfully
3. ✓ Staff view loads with tabs
4. ✓ Blue plus icon visible in top right
5. ✓ Tap plus icon
6. ✓ Booking view appears full screen
7. ✓ Select "Repair"
8. ✓ Enter customer info
9. ✓ Continue to devices
10. ✓ Add a device
11. ✓ Continue to summary
12. ✓ Continue to signature
13. ✓ Agree to terms
14. ✓ Sign or type name
15. ✓ Tap "Complete Booking"
16. ✓ See confirmation with order number
17. ✓ Tap "Done"
18. ✓ Returns to staff view

---

## Handoff Notes

- This completes the New Booking feature
- All stages are now complete
- Feature accessible via blue plus icon in toolbar
- Future enhancements:
  - Ticket linking (link enquiry to order)
  - Sub-location assignment
  - Engineer assignment
  - Accessories wizard implementation
