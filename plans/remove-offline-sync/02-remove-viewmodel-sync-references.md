# Stage 02: Remove ViewModel Sync References

## Objective

Remove all SyncEngine references and sync-related properties from ViewModels.

## Dependencies

**Requires:** Stage 01 complete (model Core Data extensions removed)

## Complexity

**Medium** - Multiple ViewModels to modify with varying complexity

## Files to Modify

| File | Changes |
|------|---------|
| `Features/Dashboard/DashboardViewModel.swift` | Remove syncEngine, sync properties, observeSyncStatus, Combine imports |
| `Features/Orders/OrderDetailViewModel.swift` | Remove syncEngine and queueChange calls |
| `Features/Devices/DeviceDetailViewModel.swift` | Remove syncEngine and queueChange calls |
| `Features/Settings/SettingsViewModel.swift` | Remove syncEngine, sync properties, syncNow method |

## Files to Create

None

## Implementation Details

### DashboardViewModel.swift

[Ref: Repair Minder/Features/Dashboard/DashboardViewModel.swift]

**Remove these imports:**
```swift
import Combine  // DELETE if only used for sync
```

**Remove these properties:**
```swift
private let syncEngine = SyncEngine.shared  // DELETE
private var cancellables = Set<AnyCancellable>()  // DELETE
var objectWillChange = ObservableObjectPublisher()  // DELETE if exists
```

**Remove these computed properties:**
```swift
var syncStatus: SyncStatus { ... }  // DELETE
var pendingChangesCount: Int { ... }  // DELETE
```

**Remove this method:**
```swift
private func observeSyncStatus() {
    syncEngine.$syncStatus
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
    // ... etc
}
```

**Remove from init():**
```swift
observeSyncStatus()  // DELETE this line
```

### OrderDetailViewModel.swift

[Ref: Repair Minder/Features/Orders/OrderDetailViewModel.swift]

**Remove this property:**
```swift
private let syncEngine = SyncEngine.shared  // DELETE
```

**Remove sync queue call** (typically in update method):
```swift
// Find and DELETE this line:
syncEngine.queueChange(.orderUpdated(id: order.id))
```

### DeviceDetailViewModel.swift

[Ref: Repair Minder/Features/Devices/DeviceDetailViewModel.swift]

**Remove this property:**
```swift
private let syncEngine = SyncEngine.shared  // DELETE
```

**Remove sync queue call** (typically in update method):
```swift
// Find and DELETE this line:
syncEngine.queueChange(.deviceUpdated(id: device.id))
```

### SettingsViewModel.swift

[Ref: Repair Minder/Features/Settings/SettingsViewModel.swift]

**Remove these properties:**
```swift
private let syncEngine = SyncEngine.shared  // DELETE
@Published var isSyncing = false  // DELETE
@Published var syncError: String?  // DELETE
```

**Remove these computed properties:**
```swift
var syncStatus: SyncStatus { syncEngine.syncStatus }  // DELETE
var lastSyncDate: Date? { syncEngine.lastSyncDate }  // DELETE
var pendingChangesCount: Int { syncEngine.pendingChangesCount }  // DELETE
```

**Remove this method entirely:**
```swift
func syncNow() async {
    isSyncing = true
    syncError = nil
    do {
        try await syncEngine.performFullSync()
    } catch {
        syncError = error.localizedDescription
    }
    isSyncing = false
}
```

## Database Changes

None

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| DashboardViewModel compiles | Build project | No errors in DashboardViewModel |
| OrderDetailViewModel compiles | Build project | No errors in OrderDetailViewModel |
| DeviceDetailViewModel compiles | Build project | No errors in DeviceDetailViewModel |
| SettingsViewModel compiles | Build project | No errors in SettingsViewModel |
| Dashboard loads | Open Dashboard tab | Stats and orders load from API |
| Order detail loads | Tap an order | Order details display correctly |

## Acceptance Checklist

- [ ] DashboardViewModel has no SyncEngine references
- [ ] DashboardViewModel has no Combine/cancellables for sync (may keep for other uses)
- [ ] OrderDetailViewModel has no SyncEngine references
- [ ] OrderDetailViewModel has no queueChange calls
- [ ] DeviceDetailViewModel has no SyncEngine references
- [ ] DeviceDetailViewModel has no queueChange calls
- [ ] SettingsViewModel has no SyncEngine references
- [ ] SettingsViewModel has no syncNow method
- [ ] Project builds successfully

## Deployment

```bash
# Build to verify changes
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | head -100
```

## Handoff Notes

After this stage:
- ViewModels no longer reference SyncEngine
- Views may still reference sync properties that no longer exist (will cause build errors)
- [See: Stage 03] will remove sync triggers from app infrastructure
- [See: Stage 04] will remove sync UI components that reference ViewModel sync properties
