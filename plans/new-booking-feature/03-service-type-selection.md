# Stage 03: Service Type Selection (BookingView)

## Objective

Create the initial service type selection screen that launches the appropriate booking flow.

## Dependencies

`[Requires: None]` - Can be built independently.

## Complexity

**Low** - Simple UI with 4 cards and navigation.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Staff/Booking/BookingView.swift` | Service type selection with 4 cards |

---

## Implementation Details

### BookingView.swift

```swift
//
//  BookingView.swift
//  Repair Minder
//

import SwiftUI

enum ServiceType: String, CaseIterable, Identifiable {
    case repair = "repair"
    case buyback = "buyback"
    case accessories = "accessories"
    case deviceSale = "device_sale"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .repair: return "Repair"
        case .buyback: return "Buyback"
        case .accessories: return "Accessories"
        case .deviceSale: return "Device Sale"
        }
    }

    var subtitle: String {
        switch self {
        case .repair: return "Book in a device for repair"
        case .buyback: return "Purchase a customer device"
        case .accessories: return "Sell accessories or parts"
        case .deviceSale: return "Sell a buyback device"
        }
    }

    var icon: String {
        switch self {
        case .repair: return "wrench.and.screwdriver.fill"
        case .buyback: return "sterlingsign.circle.fill"
        case .accessories: return "bag.fill"
        case .deviceSale: return "tag.fill"
        }
    }

    var color: Color {
        switch self {
        case .repair: return .blue
        case .buyback: return .green
        case .accessories: return .purple
        case .deviceSale: return .orange
        }
    }
}

struct BookingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedServiceType: ServiceType?
    @State private var showDeviceSaleAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Service Type Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(ServiceType.allCases) { serviceType in
                        ServiceTypeCard(serviceType: serviceType) {
                            handleServiceSelection(serviceType)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
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
                if serviceType == .accessories {
                    AccessoriesPlaceholderView()
                } else {
                    BookingWizardView(serviceType: serviceType)
                }
            }
            .alert("Device Sale", isPresented: $showDeviceSaleAlert) {
                Button("Go to Buyback") {
                    // Navigate to buyback/devices list
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Make sure the device is at the 'For Sale' status and click 'Sell Now' on the device details.")
            }
        }
    }

    private func handleServiceSelection(_ serviceType: ServiceType) {
        if serviceType == .deviceSale {
            showDeviceSaleAlert = true
        } else {
            selectedServiceType = serviceType
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

// MARK: - Accessories Placeholder

struct AccessoriesPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bag.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)

            VStack(spacing: 8) {
                Text("Accessories")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Accessories sales wizard is coming soon.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Accessories")
        .navigationBarTitleDisplayMode(.inline)
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

### Test 1: Service Type Display
- All 4 service types display with correct icons and labels
- Grid layout shows 2x2

### Test 2: Repair Selection
- Tap "Repair" card
- Navigates to BookingWizardView with serviceType = .repair

### Test 3: Buyback Selection
- Tap "Buyback" card
- Navigates to BookingWizardView with serviceType = .buyback

### Test 4: Accessories Selection
- Tap "Accessories" card
- Shows placeholder view

### Test 5: Device Sale Selection
- Tap "Device Sale" card
- Shows alert with instructions
- "Go to Buyback" dismisses view
- "Cancel" dismisses alert

### Test 6: Dismiss
- Tap X button
- View dismisses

---

## Acceptance Checklist

- [ ] `BookingView.swift` created
- [ ] `ServiceType` enum with all 4 cases
- [ ] `ServiceTypeCard` component renders correctly
- [ ] Navigation to `BookingWizardView` works for repair/buyback
- [ ] Accessories shows placeholder
- [ ] Device Sale shows alert
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

- `ServiceType` enum is used throughout the booking flow
- Navigation uses `navigationDestination(item:)` pattern
- [See: Stage 04] will implement `BookingWizardView` that this navigates to
- [See: Stage 10] will wire this up to blue plus icon in toolbar
