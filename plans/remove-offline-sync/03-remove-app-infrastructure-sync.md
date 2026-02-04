# Stage 03: Remove App Infrastructure Sync Triggers

## Objective

Remove all sync triggers from app entry points including AppState, AppDelegate, DeepLinkHandler, and the main app file.

## Dependencies

**Requires:** Stage 02 complete (ViewModel sync references removed)

## Complexity

**Medium** - Multiple app infrastructure files to modify

## Files to Modify

| File | Changes |
|------|---------|
| `App/AppState.swift` | Remove sync properties, setupSyncObservation, performSync, sync from checkAuthStatus |
| `App/AppDelegate.swift` | Remove SyncEngine.performFullSync from push notification handler |
| `Core/Notifications/DeepLinkHandler.swift` | Remove SyncEngine.performFullSync call |
| `Repair_MinderApp.swift` | Remove background task registration and handling |

## Files to Create

None

## Implementation Details

### AppState.swift

[Ref: Repair Minder/App/AppState.swift]

**Remove these imports (if only used for sync):**
```swift
import Combine  // DELETE if only used for sync observation
```

**Remove these properties:**
```swift
@Published var syncStatus: SyncStatus = .idle  // DELETE
@Published var lastSyncDate: Date?  // DELETE
@Published var pendingChangesCount: Int = 0  // DELETE
private var observers = Set<AnyCancellable>()  // DELETE if only used for sync
```

**Remove these computed properties:**
```swift
var isSyncing: Bool { syncStatus == .syncing }  // DELETE
var isOffline: Bool { !NetworkMonitor.shared.isConnected }  // KEEP or DELETE based on offline banner needs
```

**Remove this method:**
```swift
func performSync() async {
    // ... sync implementation
}
```

**Remove this method:**
```swift
private func setupSyncObservation() {
    SyncEngine.shared.$syncStatus
        .receive(on: DispatchQueue.main)
        .assign(to: &$syncStatus)
    // ... etc
}
```

**Modify checkAuthStatus() - remove sync trigger:**
```swift
func checkAuthStatus() async {
    // ... existing auth logic ...

    // DELETE these lines:
    if isAuthenticated {
        await SyncEngine.shared.performFullSync()
    }
}
```

**Remove from init() if present:**
```swift
setupSyncObservation()  // DELETE
```

### AppDelegate.swift

[Ref: Repair Minder/App/AppDelegate.swift]

**Remove sync trigger from push notification handler:**

Find `userNotificationCenter(_:willPresent:withCompletionHandler:)` and remove:
```swift
// DELETE this block:
Task {
    await SyncEngine.shared.performFullSync()
}
```

### DeepLinkHandler.swift

[Ref: Repair Minder/Core/Notifications/DeepLinkHandler.swift]

**Remove sync trigger from handle method:**

Find `handle(userInfo:)` or similar method and remove:
```swift
// DELETE this line:
await SyncEngine.shared.performFullSync()
```

Keep the navigation logic intact.

### Repair_MinderApp.swift

[Ref: Repair Minder/Repair_MinderApp.swift]

**Remove background tasks import:**
```swift
import BackgroundTasks  // DELETE
```

**Remove from init():**
```swift
registerBackgroundTasks()  // DELETE
```

**Remove this method entirely:**
```swift
private func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.mendmyi.repairminder.sync",
        using: nil
    ) { task in
        self.handleBackgroundSync(task: task as! BGAppRefreshTask)
    }
}
```

**Remove this method entirely:**
```swift
private func handleBackgroundSync(task: BGAppRefreshTask) {
    task.expirationHandler = {
        task.setTaskCompleted(success: false)
    }
    Task {
        do {
            try await SyncEngine.shared.performFullSync()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }
    // Schedule next sync...
}
```

**Remove background notification handler if present:**
```swift
.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
    // Schedule background sync...
}
```

## Database Changes

None

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| AppState compiles | Build project | No errors in AppState |
| AppDelegate compiles | Build project | No errors in AppDelegate |
| App launches | Launch in simulator | App starts without crash |
| Login works | Enter credentials | User authenticates, dashboard loads |
| Push notification | Send test notification | App navigates correctly (no sync) |

## Acceptance Checklist

- [ ] AppState has no SyncEngine references
- [ ] AppState has no sync-related published properties
- [ ] AppState.checkAuthStatus does not trigger sync
- [ ] AppDelegate does not call SyncEngine on push notification
- [ ] DeepLinkHandler does not call SyncEngine
- [ ] Repair_MinderApp has no background task registration
- [ ] Repair_MinderApp has no handleBackgroundSync method
- [ ] Project builds successfully
- [ ] App launches successfully

## Deployment

```bash
# Build and run to verify
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 16' build

# Launch app in simulator to test
xcrun simctl boot "iPhone 16" 2>/dev/null || true
xcrun simctl install "iPhone 16" build/Debug-iphonesimulator/Repair\ Minder.app
xcrun simctl launch "iPhone 16" com.mendmyi.repairminder
```

## Handoff Notes

After this stage:
- App no longer triggers sync on any event
- SyncEngine is no longer called from anywhere except possibly UI components
- [See: Stage 04] will remove sync UI components
- [See: Stage 05] will delete the actual SyncEngine file
