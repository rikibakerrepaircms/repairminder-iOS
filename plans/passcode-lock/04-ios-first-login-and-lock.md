# Stage 04 — iOS: First Login Flow & App Lock

## Objective

Wire passcode setup into the first-login flow (prompt users to set a passcode with the option to skip) and add scene phase monitoring to lock the app on return from background.

## Dependencies

`[Requires: Stage 02 complete]` — Needs `PasscodeService` with `hasPasscode` state.
`[Requires: Stage 03 complete]` — Needs `SetPasscodeView` and `PasscodeLockView`.

## Complexity

**Medium** — App state machine changes, scene phase lifecycle, overlay integration.

---

## Files to Create

None — this stage wires existing components together.

---

## Files to Modify

### 1. `App/AppState.swift`

**Add `passcodeSetup` state** for first-login passcode creation.

Add new case to `AppViewState`:
```swift
enum AppViewState: Equatable {
    case loading
    case roleSelection
    case staffLogin
    case customerLogin
    case passcodeSetup        // NEW — user needs to set passcode
    case staffDashboard
    case customerPortal
    case quarantine(reason: String)
}
```

**Modify `onStaffAuthenticated()`** to check passcode:
```swift
func onStaffAuthenticated() {
    switch authManager.authState {
    case .authenticated:
        if !PasscodeService.shared.hasPasscode && !hasSeenPasscodeSetup {
            currentState = .passcodeSetup
        } else {
            currentState = .staffDashboard
        }
    case .quarantined(let reason):
        currentState = .quarantine(reason: reason)
    default:
        break
    }
}
```

**Add `hasSeenPasscodeSetup` flag** (persisted per user so the prompt shows once):
```swift
/// Tracks whether user has seen the passcode setup prompt this install.
/// Stored in UserDefaults keyed by user ID so different users get prompted.
private var hasSeenPasscodeSetup: Bool {
    guard let userId = authManager.currentUser?.id else { return false }
    return UserDefaults.standard.bool(forKey: "passcodeSetup_seen_\(userId)")
}

func markPasscodeSetupSeen() {
    guard let userId = authManager.currentUser?.id else { return }
    UserDefaults.standard.set(true, forKey: "passcodeSetup_seen_\(userId)")
}
```

**Add `onPasscodeSet()` and `onPasscodeSetupSkipped()`** to transition after passcode setup:
```swift
func onPasscodeSet() {
    markPasscodeSetupSeen()
    currentState = .staffDashboard
}

func onPasscodeSetupSkipped() {
    markPasscodeSetupSeen()
    currentState = .staffDashboard
}
```

**Modify `checkStaffSession()`** to check passcode after auth:
```swift
private func checkStaffSession() async {
    await authManager.checkExistingSession()

    switch authManager.authState {
    case .authenticated:
        if !PasscodeService.shared.hasPasscode && !hasSeenPasscodeSetup {
            currentState = .passcodeSetup
        } else {
            currentState = .staffDashboard
        }
    case .quarantined(let reason):
        currentState = .quarantine(reason: reason)
    default:
        currentState = .staffLogin
    }
}
```

### 2. `Repair_MinderApp.swift`

**Major changes:**
- Add `@Environment(\.scenePhase)` for lifecycle monitoring
- Add `@ObservedObject` for `PasscodeService.shared`
- Add `@State` for background timestamp
- Add `PasscodeLockView` overlay in `ZStack`
- Add `passcodeSetup` case to `RootView`
- Add `onChange(of: scenePhase)` handler

**Updated `Repair_MinderApp`:**
```swift
@main
struct Repair_MinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @ObservedObject private var passcodeService = PasscodeService.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var backgroundTime: Date?

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(appState)
                    .onOpenURL { url in
                        _ = DeepLinkHandler.shared.handleURL(url)
                    }

                if passcodeService.isLocked {
                    PasscodeLockView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: passcodeService.isLocked)
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            backgroundTime = Date()
        case .active:
            if let bg = backgroundTime {
                let duration = Date().timeIntervalSince(bg)
                if passcodeService.passcodeEnabled && passcodeService.shouldLockOnForeground(backgroundDuration: duration) {
                    passcodeService.lockApp()
                }
            }
            backgroundTime = nil
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
```

**Updated `RootView`** — add `.passcodeSetup` case:
```swift
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.currentState {
            case .loading:
                LoadingView()
            case .roleSelection:
                RoleSelectionView()
            case .staffLogin:
                StaffLoginView()
            case .customerLogin:
                CustomerLoginView()
            case .passcodeSetup:
                PasscodeSetupView()   // NEW
            case .staffDashboard:
                StaffMainView()
            case .customerPortal:
                CustomerOrderListView()
            case .quarantine(let reason):
                QuarantineView(reason: reason)
            }
        }
        .task {
            await appState.initialize()
        }
    }
}
```

**Add `PasscodeSetupView`** (inline in Repair_MinderApp.swift or separate file):
```swift
/// Shown after first login when user hasn't set a passcode.
/// Has a "Set up later" button — setup is OPTIONAL per master plan.
private struct PasscodeSetupView: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        NavigationStack {
            SetPasscodeView(mode: .create) { success in
                if success {
                    appState.onPasscodeSet()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Set up later") {
                        appState.onPasscodeSetupSkipped()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
```

### 3. Xcode Project — Info.plist

**Add `NSFaceIDUsageDescription`.**

Check which approach the project uses — if there's an Info.plist file, add:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Repair Minder uses Face ID to unlock the app securely.</string>
```

If using build settings (`INFOPLIST_KEY_*`), add to both Debug and Release:
```
INFOPLIST_KEY_NSFaceIDUsageDescription = "Repair Minder uses Face ID to unlock the app securely.";
```

---

## Database Changes

None.

---

## Test Cases

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 1 | First login — no passcode | Login via magic link (hasPasscode=false) | Shows `SetPasscodeView`, not dashboard |
| 2 | First login — set passcode | Enter PIN → confirm | Dashboard shown |
| 3 | Subsequent login — has passcode | Login (hasPasscode=true) | Goes directly to dashboard |
| 4 | Lock on background return | Dashboard → background 16+ min → return | Lock screen shown |
| 5 | No lock within timeout | Dashboard → background 5 min → return | No lock (15-min default) |
| 6 | No lock when no passcode | User without passcode → background → return | No lock |
| 7 | Unlock with PIN | Lock screen → correct PIN | Dashboard visible |
| 8 | Unlock with biometric | Lock screen → Face ID | Dashboard visible |
| 9 | Wrong PIN | Lock screen → wrong PIN | Shake, retry |
| 10 | Forgot PIN → logout | Lock → Forgot → Logout | Returns to login |
| 11 | Forgot PIN → reset email | Lock → Forgot → Send Email | Reset flow shown |
| 12 | Lock overlay covers tabs | Lock while on any tab | All tabs hidden behind lock |
| 13 | Skip passcode setup | Tap "Set up later" on setup screen | Transitions to dashboard without passcode |
| 14 | Setup only shown once | Skip setup → close app → reopen | Goes directly to dashboard (not setup again) |
| 15 | No lock when disabled | `passcodeEnabled = false` → background → return | No lock screen |

**Important:** The `PasscodeSetupView` wraps `SetPasscodeView` and adds a "Set up later" toolbar button. The cancel button on `SetPasscodeView` itself calls `onComplete(false)` which the wrapper should ignore (only the "Set up later" button transitions to dashboard).

---

## Acceptance Checklist

- [ ] `AppViewState.passcodeSetup` case added
- [ ] First login with `hasPasscode == false` shows passcode setup prompt
- [ ] Passcode setup has "Set up later" skip option
- [ ] After setting passcode, transitions to dashboard
- [ ] After skipping, transitions to dashboard (setup not shown again)
- [ ] Returning login with `hasPasscode == true` goes to dashboard
- [ ] `scenePhase` monitoring records background time
- [ ] Lock triggers after configurable timeout (default 15 min)
- [ ] Lock does NOT trigger within timeout period
- [ ] `PasscodeLockView` overlay covers entire app
- [ ] Opacity animation on lock/unlock
- [ ] `NSFaceIDUsageDescription` in project
- [ ] Project builds and runs

---

## Deployment & Simulator Verification

```bash
# Build and run on simulator:
mcp__XcodeBuildMCP__build_run_sim
# Project: /Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj
# Simulator: iPhone 16 Pro

# Login with test account:
# 1. Request magic link for rikibaker+admin@gmail.com
# 2. Get code from D1:
cd "/Volumes/Riki Repos/repairminder" && npx wrangler d1 execute repairminder_database --remote --json --command "SELECT magic_link_code FROM users WHERE email = 'rikibaker+admin@gmail.com'" 2>/dev/null | jq -r '.[0].results[0].magic_link_code'
# 3. Enter code in app to login

# Test first-login passcode prompt:
# 1. Clear passcode for test user via DB:
cd "/Volumes/Riki Repos/repairminder" && npx wrangler d1 execute repairminder_database --remote --command "UPDATE users SET passcode_hash = NULL, passcode_salt = NULL, passcode_enabled = 0 WHERE email = 'rikibaker+admin@gmail.com'"
# 2. Login in app → should show passcode setup prompt (with "Set up later" skip option)
# 3. Set passcode → should show dashboard
# 4. OR skip → should show dashboard without passcode

# Test lock (set timeout to 1 min for testing):
cd "/Volumes/Riki Repos/repairminder" && npx wrangler d1 execute repairminder_database --remote --command "UPDATE users SET passcode_timeout_minutes = 1 WHERE email = 'rikibaker+admin@gmail.com'"
# 1. Cmd+Shift+H to background simulator
# 2. Wait > 1 minute
# 3. Return to app → lock screen should show
# 4. Enter PIN → should unlock
```

---

## Handoff Notes

- The first-login flow is now gated: auth → passcode check → setup or dashboard
- Lock overlay sits above ALL app content (including tab bar)
- `SetPasscodeView` may need a small adjustment to hide cancel button in `.create` mode when used for mandatory setup — check if the `PasscodeSetupView` wrapper handles this correctly
- Settings (change, timeout, biometric toggle) are wired in [See: Stage 05]
