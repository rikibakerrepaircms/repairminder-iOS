# Remaining Plan Fixes — Worker Prompt

## Context

You are working on the **Repair Minder iOS** app's **New Booking Feature**. The feature has been planned across 11 plan files (`00-master-plan.md` through `11-audit-fixes.md`) in the directory:

```
/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/new-booking-feature/
```

A thorough audit was conducted against the actual backend API handlers (Cloudflare Workers at `/Volumes/Riki Repos/repairminder/worker/`) and the iOS codebase. Most fixes from the audit have **already been applied** to the plan files. The items below are the **remaining unfixed issues** that still need to be applied to the plan file code blocks.

**Important:** You are editing **plan files** (markdown with embedded Swift code blocks), NOT actual Swift source files. These plans will be used by a future worker to implement the feature.

---

## Fix A: Device Type Picker — Filter Out System Types

**Severity:** MINOR
**File:** `plans/new-booking-feature/06-devices-step.md`
**Location:** `DeviceEntryFormView` code block, line 215

### Problem

The device type picker in `DeviceEntryFormView` shows ALL device types from `viewModel.deviceTypes` without filtering. The backend (`device_types_handlers.js` → `handleListDeviceTypes`) returns device types including system-created types (where `is_system = true`, e.g. "Repair" and "Buyback"). These system types are workflow markers, not user-selectable device categories. Staff should only see custom company-created types in the picker.

### Current Code (line 215)

```swift
ForEach(viewModel.deviceTypes) { type in
```

### Fix

Change to:

```swift
ForEach(viewModel.deviceTypes.filter { $0.isSystem != true }) { type in
```

Also update the guard condition at line 207 to match:

**Current:**
```swift
if !viewModel.deviceTypes.isEmpty {
```

**Change to:**
```swift
let selectableTypes = viewModel.deviceTypes.filter { $0.isSystem != true }
if !selectableTypes.isEmpty {
```

And update the `ForEach` to use the filtered array:
```swift
ForEach(selectableTypes) { type in
```

### Verification

After editing, the Device Type picker section in `DeviceEntryFormView` should look like:

```swift
// Device Type
let selectableTypes = viewModel.deviceTypes.filter { $0.isSystem != true }
if !selectableTypes.isEmpty {
    VStack(alignment: .leading, spacing: 8) {
        Text("Device Type")
            .font(.subheadline)
            .fontWeight(.medium)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectableTypes) { type in
                    Button {
                        device.deviceTypeId = type.id
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.systemImage)
                            Text(type.name)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(device.deviceTypeId == type.id ? Color.accentColor : Color(.systemGray6))
                        .foregroundStyle(device.deviceTypeId == type.id ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
```

Also update the comment at lines 204-206 to reflect the filtering:
```swift
// Device types: only show custom (non-system) types.
// System types like "Repair" and "Buyback" are workflow markers,
// not user-selectable categories.
```

---

## Fix B: Buyback Icon Inconsistency in DeviceListItemView

**Severity:** MINOR
**File:** `plans/new-booking-feature/06-devices-step.md`
**Location:** `DeviceListItemView` code block, line 508

### Problem

`DeviceListItemView` uses `sterlingsign.circle` as the buyback workflow icon. This is currency-specific (British pounds). All other plan files use the currency-neutral `arrow.triangle.2.circlepath`:

- Stage 01 (`01-models-and-api-endpoints.md` line 267): `arrow.triangle.2.circlepath`
- Stage 03 (`03-service-type-selection.md`): `arrow.triangle.2.circlepath`
- Stage 07 (`07-summary-step.md` line 343): `arrow.triangle.2.circlepath`
- The audit notes in `11-audit-fixes.md` line 354 confirm this convention

### Current Code (line 508)

```swift
private var workflowIcon: String {
    device.workflowType == .buyback ? "sterlingsign.circle" : "wrench.and.screwdriver"
}
```

### Fix

```swift
private var workflowIcon: String {
    device.workflowType == .buyback ? "arrow.triangle.2.circlepath" : "wrench.and.screwdriver"
}
```

---

## Fix C: Location Load Failure — Silent Error

**Severity:** MAJOR
**File:** `plans/new-booking-feature/02-booking-view-model.md`
**Location:** `BookingViewModel` code block, `loadLocations()` method (around line 482)

### Problem

`loadLocations()` catches errors and logs them, but does NOT surface the failure to the user. If the locations API call fails (network error, 401, etc.), `locations` remains an empty array `[]`. The downstream consequences:

1. The location selector in `ClientStepView` won't show (it only renders when `locations.count > 1`)
2. `formData.locationId` stays empty
3. `isCurrentStepValid` for the client step checks `locations.count < 2 || !formData.locationId.isEmpty` — if locations is empty, this evaluates to `true` (since 0 < 2), allowing the user to proceed
4. The backend's `handleCreateOrder` checks: if the company HAS locations but no `location_id` was sent, it returns `400: "Location is required for this company"` — the booking silently fails at submit

### Current Code

```swift
func loadLocations() async {
    isLoadingLocations = true
    defer { isLoadingLocations = false }

    do {
        let result: [Location] = try await APIClient.shared.request(.locations)
        locations = result

        // Auto-select if only one location
        if locations.count == 1 {
            formData.locationId = locations[0].id
        }
    } catch {
        logger.error("Failed to load locations: \(error)")
    }
}
```

### Fix

Set `errorMessage` when locations fail to load so the UI can inform the user:

```swift
func loadLocations() async {
    isLoadingLocations = true
    defer { isLoadingLocations = false }

    do {
        let result: [Location] = try await APIClient.shared.request(.locations)
        locations = result

        // Auto-select if only one location
        if locations.count == 1 {
            formData.locationId = locations[0].id
        }
    } catch {
        logger.error("Failed to load locations: \(error)")
        errorMessage = "Failed to load locations. Please check your connection and try again."
    }
}
```

Additionally, the wizard container (`04-wizard-container.md`) should show this error. In `BookingWizardView`'s body, add an error banner before the step content (inside the main VStack, after the Divider):

In `plans/new-booking-feature/04-wizard-container.md`, after the `Divider()` on line 65 and before the `// Step Content` comment on line 67, add:

```swift
// Error Banner
if let error = viewModel.errorMessage {
    HStack {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
        Text(error)
            .font(.caption)
        Spacer()
        Button("Retry") {
            viewModel.errorMessage = nil
            Task { await viewModel.loadInitialData() }
        }
        .font(.caption)
        .fontWeight(.medium)
    }
    .padding()
    .background(Color.orange.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding(.horizontal)
}
```

---

## Fix D: Update 11-audit-fixes.md Status

**File:** `plans/new-booking-feature/11-audit-fixes.md`

### Problem

The acceptance checklist at the bottom (lines 366-385) has all items checked `[x]`, including Fix 6 (device type filter). But Fix 6 was NOT actually applied to the Stage 06 code block. This is misleading for future workers.

### Fix

Add a note at the top of the file (after line 5) clarifying status:

```markdown
**Status:** Fixes 1–5 have been applied to plan files. Fix 6 is documented here but has NOT yet been applied to Stage 06's code block — see `12-remaining-fixes-prompt.md` for the remaining fixes.
```

---

## Summary of All Changes

| Fix | Severity | File to Edit | What to Change |
|-----|----------|-------------|----------------|
| A | MINOR | `06-devices-step.md` | Filter system device types from picker: `viewModel.deviceTypes.filter { $0.isSystem != true }` |
| B | MINOR | `06-devices-step.md` | Change buyback icon from `sterlingsign.circle` to `arrow.triangle.2.circlepath` |
| C | MAJOR | `02-booking-view-model.md` + `04-wizard-container.md` | Surface location load failure to user via `errorMessage` + error banner |
| D | INFO | `11-audit-fixes.md` | Update status note to reflect Fix 6 was not applied |

## Implementation Order

1. Fix A (Stage 06 device type filter)
2. Fix B (Stage 06 buyback icon)
3. Fix C (Stage 02 + Stage 04 location error handling)
4. Fix D (Stage 11 status update)

All fixes are to **plan markdown files**, not Swift source files. Edit the embedded code blocks within the markdown.

## Verification

After applying all fixes, do a final grep to confirm:

```bash
# Fix A: No unfiltered deviceTypes in picker
grep -n "ForEach(viewModel.deviceTypes)" plans/new-booking-feature/06-devices-step.md
# Should return 0 results

# Fix B: No sterlingsign icons
grep -rn "sterlingsign" plans/new-booking-feature/
# Should return 0 results

# Fix C: errorMessage is set in loadLocations
grep -n "errorMessage" plans/new-booking-feature/02-booking-view-model.md
# Should return at least 1 result inside loadLocations()
```
