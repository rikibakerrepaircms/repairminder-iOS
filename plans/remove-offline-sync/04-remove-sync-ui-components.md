# Stage 04: Remove Sync UI Components

## Objective

Remove all sync-related UI components including banners, buttons, and status displays from views.

## Dependencies

**Requires:** Stage 03 complete (app infrastructure sync triggers removed)

## Complexity

**Medium** - Multiple view files to modify, some components to delete

## Files to Modify

| File | Changes |
|------|---------|
| `Features/Dashboard/DashboardView.swift` | Remove SyncStatusBanner usage |
| `Features/Settings/SettingsView.swift` | Remove Data section (sync button, status), update logout message |
| `Features/Settings/DebugView.swift` | Remove sync section, force sync, clear cache |
| `Shared/Components/OfflineBanner.swift` | Update message or consider removal |

## Files to Delete

| File | Reason |
|------|--------|
| `Features/Dashboard/Components/SyncStatusBanner.swift` | No longer needed |
| `Features/Settings/Components/SyncStatusRow.swift` | No longer needed |

## Implementation Details

### DashboardView.swift

[Ref: Repair Minder/Features/Dashboard/DashboardView.swift]

**Find and remove SyncStatusBanner:**
```swift
// DELETE this view usage (location varies):
SyncStatusBanner()

// Or if conditional:
if viewModel.syncStatus != .idle {
    SyncStatusBanner()
}
```

### SettingsView.swift

[Ref: Repair Minder/Features/Settings/SettingsView.swift]

**Remove the entire "Data" section:**
```swift
// DELETE this entire Section:
Section("Data") {
    SyncStatusRow(
        status: viewModel.syncStatus,
        lastSyncDate: viewModel.lastSyncDate,
        pendingCount: viewModel.pendingChangesCount
    )

    Button(action: {
        Task {
            await viewModel.syncNow()
        }
    }) {
        HStack {
            if viewModel.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            }
            Text(viewModel.isSyncing ? "Syncing..." : "Sync Now")
        }
    }
    .disabled(viewModel.isSyncing)

    if let error = viewModel.syncError {
        Text(error)
            .foregroundColor(.red)
            .font(.caption)
    }
}
```

**Update logout confirmation message:**

Find the logout confirmation dialog and update:
```swift
// BEFORE:
.alert("Logout", isPresented: $showLogoutConfirmation) {
    // ...
} message: {
    Text("Are you sure you want to logout? Any unsynced changes will be saved locally.")
}

// AFTER:
.alert("Logout", isPresented: $showLogoutConfirmation) {
    // ...
} message: {
    Text("Are you sure you want to logout?")
}
```

### DebugView.swift

[Ref: Repair Minder/Features/Settings/DebugView.swift]

**Remove CoreData import:**
```swift
import CoreData  // DELETE
```

**Remove sync-related properties:**
```swift
@ObservedObject private var syncEngine = SyncEngine.shared  // DELETE
```

**Remove the entire "Sync" section:**
```swift
// DELETE this entire Section:
Section("Sync") {
    HStack {
        Text("Status")
        Spacer()
        Text(statusDescription)
            .foregroundColor(statusColor)
    }

    HStack {
        Text("Last Sync")
        Spacer()
        Text(syncEngine.lastSyncDate?.formatted() ?? "Never")
            .foregroundColor(.secondary)
    }

    HStack {
        Text("Pending Changes")
        Spacer()
        Text("\(syncEngine.pendingChangesCount)")
            .foregroundColor(.secondary)
    }
}
```

**Remove "Force Sync" button:**
```swift
// DELETE:
Button("Force Sync") {
    Task {
        try? await syncEngine.performFullSync()
    }
}
```

**Remove "Clear Local Cache" button:**
```swift
// DELETE:
Button("Clear Local Cache", role: .destructive) {
    clearCache()
}
```

**Remove computed properties for sync status:**
```swift
// DELETE:
private var statusDescription: String {
    switch syncEngine.syncStatus {
    case .idle: return "Idle"
    case .syncing: return "Syncing..."
    case .error(let msg): return "Error: \(msg)"
    }
}

private var statusColor: Color {
    // ...
}
```

**Remove clearCache function:**
```swift
// DELETE:
private func clearCache() {
    // Core Data clearing logic
}
```

### OfflineBanner.swift

[Ref: Repair Minder/Shared/Components/OfflineBanner.swift]

**Option A: Update the message (recommended if keeping offline indicator):**
```swift
// BEFORE:
Text("You're offline. Changes will sync when reconnected.")

// AFTER:
Text("You're offline. Check your connection.")
```

**Option B: If removing offline indicator entirely:**
Mark file for deletion and remove usage from ContentView.swift

### Delete Component Files

**SyncStatusBanner.swift:**
```bash
rm "Repair Minder/Features/Dashboard/Components/SyncStatusBanner.swift"
```

**SyncStatusRow.swift:**
```bash
rm "Repair Minder/Features/Settings/Components/SyncStatusRow.swift"
```

## Database Changes

None

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Dashboard displays | Open Dashboard | No sync banner visible, stats load |
| Settings displays | Open Settings | No Data section, clean settings list |
| Debug view displays | Open Debug | No Sync section, network/auth info visible |
| Logout works | Tap logout, confirm | User logs out, message doesn't mention sync |

## Acceptance Checklist

- [ ] DashboardView has no SyncStatusBanner
- [ ] SettingsView has no Data section
- [ ] SettingsView logout message doesn't mention "unsynced changes"
- [ ] DebugView has no Sync section
- [ ] DebugView has no Force Sync button
- [ ] DebugView has no Clear Cache button
- [ ] SyncStatusBanner.swift deleted
- [ ] SyncStatusRow.swift deleted
- [ ] OfflineBanner message updated (or file deleted)
- [ ] Project builds successfully
- [ ] All views render correctly in simulator

## Deployment

```bash
# Delete component files
rm "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder/Features/Dashboard/Components/SyncStatusBanner.swift"
rm "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder/Features/Settings/Components/SyncStatusRow.swift"

# Build to verify
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Handoff Notes

After this stage:
- No sync-related UI is visible to users
- SyncEngine is no longer referenced by any UI
- [See: Stage 05] will delete the Core Data infrastructure files
- [See: Stage 06] will clean up Xcode project references
