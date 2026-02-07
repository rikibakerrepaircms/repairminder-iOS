# Stage 03: Service Type Selection (BookingView)

## Objective

Create the initial service type selection screen that launches the appropriate booking flow.

## Dependencies

`[Requires: Stage 02 complete]` - Needs `BookingViewModel` for state management, `buybackEnabled` flag, and `loadInitialData()`.

## Complexity

**Low** - Simple UI with 2 cards (repair/buyback) and navigation. Only `ServiceType` cases where `isAvailable == true` are shown.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Booking/BookingView.swift` | Service type selection with available service cards |

---

## Design Decisions

> **Why only 2 service types?** Stage 01 defines 4 `ServiceType` enum cases (`.repair`, `.buyback`, `.accessories`, `.deviceSale`) but marks `.accessories` and `.deviceSale` as `isAvailable = false` because the backend `POST /api/orders` has no dedicated booking wizard flow for them. This view only shows types where `isAvailable == true`. If buyback is disabled for the company (via `CompanyPublicInfo.buybackEnabled`), only `.repair` is shown — and in that case we skip this screen entirely and go straight to the wizard.
>
> **Backend reference:** `GET /api/company/public-info` returns `buyback_enabled: Boolean(company.buyback_enabled)` (see `worker/index.js` ~line 10855). The `CompanyPublicInfo` model (Stage 01/02) decodes this as `buybackEnabled: Bool?` with Bool-or-Int handling.

---

## Implementation Details

### BookingView.swift

```swift
//
//  BookingView.swift
//  Repair Minder
//

import SwiftUI

// NOTE: ServiceType enum is defined in Core/Models/ServiceType.swift (Stage 01)
// NOTE: BookingViewModel is defined in Features/Staff/Booking/BookingViewModel.swift (Stage 02)

struct BookingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedServiceType: ServiceType?
    @State private var viewModel = BookingViewModel()

    /// Filtered service types: only those with backend support AND enabled by company settings.
    /// Uses `isAvailable` (Stage 01) to exclude .accessories/.deviceSale which lack backend flows,
    /// and `buybackEnabled` (from CompanyPublicInfo API) to conditionally hide .buyback.
    var availableServiceTypes: [ServiceType] {
        ServiceType.allCases.filter { type in
            guard type.isAvailable else { return false }
            switch type {
            case .buyback:
                return viewModel.buybackEnabled
            default:
                return true
            }
        }
    }

    /// True while initial data (locations, device types, company info) is still loading.
    /// We wait for this before showing cards so the buybackEnabled flag is resolved
    /// and we don't flash cards that will disappear.
    var isLoading: Bool {
        viewModel.isLoadingLocations
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Loading...")
                } else if availableServiceTypes.count == 1,
                          let onlyType = availableServiceTypes.first {
                    // Only one available type (e.g. buyback disabled) — skip selection,
                    // go straight to wizard
                    Color.clear
                        .onAppear {
                            selectedServiceType = onlyType
                        }
                } else {
                    Spacer()

                    // Service Type Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(availableServiceTypes) { serviceType in
                            ServiceTypeCard(serviceType: serviceType) {
                                selectedServiceType = serviceType
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("New Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(item: $selectedServiceType) { serviceType in
                BookingWizardView(viewModel: viewModel, serviceType: serviceType, onComplete: {
                    dismiss()
                })
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
}

// MARK: - Service Type Card

struct ServiceTypeCard: View {
    let serviceType: ServiceType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Circle()
                    .fill(serviceType.color.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: serviceType.icon)
                            .font(.system(size: 32))
                            .foregroundStyle(serviceType.color)
                    }

                VStack(spacing: 4) {
                    Text(serviceType.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(serviceType.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BookingView()
}

#Preview("Service Card") {
    ServiceTypeCard(serviceType: .repair) {}
        .frame(width: 180)
        .padding()
        .background(Color(.systemGroupedBackground))
}
```

---

## Database Changes

**None**

---

## Test Cases

### Test 1: Service Type Display (buyback enabled)
- With `buybackEnabled = true` (default), 2 service types display: Repair and Buyback
- `.accessories` and `.deviceSale` are NOT shown (they have `isAvailable = false`)
- Grid layout shows 1x2

### Test 2: Service Type Display (buyback disabled)
- With `buybackEnabled = false`, only Repair is available
- View auto-navigates to BookingWizardView with `.repair` (skips selection screen)

### Test 3: Repair Selection
- Tap "Repair" card
- Navigates to BookingWizardView with serviceType = .repair

### Test 4: Buyback Selection
- Tap "Buyback" card
- Navigates to BookingWizardView with serviceType = .buyback

### Test 5: Dismiss
- Tap X button
- View dismisses

### Test 6: Loading State
- While `loadInitialData()` is in progress, a loading spinner is shown
- Cards only appear after loading completes (so `buybackEnabled` is resolved)

---

## Acceptance Checklist

- [ ] `BookingView.swift` created
- [ ] Only service types with `isAvailable == true` are shown (currently: `.repair`, `.buyback`)
- [ ] `.buyback` is further gated by `viewModel.buybackEnabled` (from CompanyPublicInfo API)
- [ ] `.accessories` and `.deviceSale` are NOT shown (no backend booking flow — `isAvailable = false`)
- [ ] When only one type is available, view auto-navigates to wizard (skips selection)
- [ ] `ServiceTypeCard` component renders correctly
- [ ] Navigation to `BookingWizardView` passes `serviceType` parameter correctly
- [ ] Loading spinner shown until `loadInitialData()` completes
- [ ] Dismiss button works
- [ ] Preview renders without error
- [ ] Project compiles without errors

---

## Deployment

```bash
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

---

## Handoff Notes

- `ServiceType` enum is defined in Stage 01 — this view only uses `.isAvailable` types
- `BookingViewModel` is defined in Stage 02 — this view creates it and passes it to the wizard
- `loadInitialData()` is called in `.task` when BookingView appears, loading locations, device types, and company info (including `buybackEnabled`) before the wizard needs them
- Navigation uses `navigationDestination(item:)` pattern — all available types go to `BookingWizardView`
- No `AccessoriesPlaceholderView` or device sale alert — unavailable types are simply not shown
- [See: Stage 04] will implement `BookingWizardView` that this navigates to
- [See: Stage 10] will wire this up to branded blue FAB overlay in StaffMainView + `.fullScreenCover { BookingView() }` presentation
