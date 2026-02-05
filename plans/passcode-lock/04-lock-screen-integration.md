# Stage 04 — Lock Screen & App Integration

## Objective

Build the lock screen overlay (`PasscodeLockView`) and integrate it into `Repair_MinderApp.swift` with scene phase monitoring so the app locks when returning from background.

## Dependencies

`[Requires: Stage 01 complete]` — Needs `PasscodeService` for lock state, verification, biometric auth.
`[Requires: Stage 02 complete]` — Needs `NumberPadView` and `ShakeEffect`.
`[Requires: Stage 03 complete]` — Settings must be functional to enable passcode for testing.

## Complexity

**Medium** — Involves SwiftUI lifecycle integration, full-screen overlay, biometric prompt, and logout flow.

---

## Files to Create

### 1. `Features/Settings/Security/PasscodeLockViewModel.swift`

**Purpose:** Manages lock screen state — PIN input, verification, biometric attempts, and forgot-PIN logout.

```swift
import SwiftUI

@MainActor
final class PasscodeLockViewModel: ObservableObject {
    @Published var enteredDigits: String = ""
    @Published var shakeCount: Int = 0
    @Published var showForgotPINAlert: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var errorMessage: String?

    let passcodeLength = 6

    private let passcodeService = PasscodeService.shared

    var canUseBiometric: Bool {
        passcodeService.isBiometricEnabled && passcodeService.isBiometricAvailable
    }

    var biometricIcon: String {
        passcodeService.biometricType.systemImage
    }

    var biometricName: String {
        passcodeService.biometricType.displayName
    }

    // MARK: - Digit Entry

    func appendDigit(_ digit: String) {
        guard enteredDigits.count < passcodeLength else { return }
        enteredDigits += digit
        errorMessage = nil

        if enteredDigits.count == passcodeLength {
            verifyPasscode()
        }
    }

    func deleteDigit() {
        guard !enteredDigits.isEmpty else { return }
        enteredDigits.removeLast()
    }

    // MARK: - Verification

    private func verifyPasscode() {
        if passcodeService.verifyPasscode(enteredDigits) {
            passcodeService.unlockApp()
        } else {
            enteredDigits = ""
            errorMessage = "Incorrect passcode"
            withAnimation {
                shakeCount += 1
            }
        }
    }

    // MARK: - Biometric

    func attemptBiometricOnAppear() {
        guard canUseBiometric && !isAuthenticating else { return }
        authenticateWithBiometric()
    }

    func authenticateWithBiometric() {
        guard !isAuthenticating else { return }
        isAuthenticating = true

        Task {
            let result = await passcodeService.authenticateWithBiometric()
            isAuthenticating = false

            switch result {
            case .success:
                passcodeService.unlockApp()
            case .failure(let error):
                switch error {
                case .biometricCancelled:
                    break // User cancelled, show PIN pad
                case .biometricFailed(let message):
                    errorMessage = message
                default:
                    break
                }
            }
        }
    }

    // MARK: - Forgot PIN

    func forceLogout() {
        passcodeService.removePasscode()

        Task {
            // Determine which auth manager to logout from
            if AuthManager.shared.authState == .authenticated {
                await AuthManager.shared.logout()
                AppState.shared.onStaffLogout()
            } else if CustomerAuthManager.shared.authState == .authenticated {
                await CustomerAuthManager.shared.logout()
                AppState.shared.onCustomerLogout()
            } else {
                await AppState.shared.fullLogout()
            }
        }
    }
}
```

### 2. `Features/Settings/Security/PasscodeLockView.swift`

**Purpose:** Full-screen lock overlay with PIN entry, biometric button, and forgot-PIN option.

```swift
import SwiftUI

struct PasscodeLockView: View {
    @StateObject private var viewModel = PasscodeLockViewModel()

    var body: some View {
        ZStack {
            // Opaque background — completely hide app content
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // App icon / logo
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.accentColor)

                Text("Enter Passcode")
                    .font(.title2)
                    .fontWeight(.semibold)

                // PIN dots
                HStack(spacing: 16) {
                    ForEach(0..<viewModel.passcodeLength, id: \.self) { index in
                        Circle()
                            .fill(index < viewModel.enteredDigits.count ? Color.accentColor : Color(.systemGray4))
                            .frame(width: 14, height: 14)
                    }
                }
                .modifier(ShakeEffect(shakes: viewModel.shakeCount))
                .animation(.default, value: viewModel.shakeCount)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                // Number pad
                NumberPadView(
                    onDigit: { viewModel.appendDigit($0) },
                    onDelete: { viewModel.deleteDigit() }
                )

                // Biometric button
                if viewModel.canUseBiometric {
                    Button(action: { viewModel.authenticateWithBiometric() }) {
                        Image(systemName: viewModel.biometricIcon)
                            .font(.system(size: 36))
                            .foregroundStyle(.accentColor)
                    }
                    .disabled(viewModel.isAuthenticating)
                    .padding(.top, 4)
                }

                // Forgot PIN
                Button("Forgot Passcode?") {
                    viewModel.showForgotPINAlert = true
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

                Spacer()
            }
            .padding()
        }
        .alert("Forgot Passcode?", isPresented: $viewModel.showForgotPINAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                viewModel.forceLogout()
            }
        } message: {
            Text("You will need to log in again. Your passcode will be removed.")
        }
        .onAppear {
            viewModel.attemptBiometricOnAppear()
        }
    }
}
```

---

## Files to Modify

### 1. `Repair_MinderApp.swift`

**Changes:**
- Add `@Environment(\.scenePhase)` property
- Add `@StateObject` for `PasscodeService.shared`
- Add `@State private var backgroundTime: Date?`
- Wrap existing `RootView()` in a `ZStack` with conditional `PasscodeLockView` overlay
- Add `.onChange(of: scenePhase)` to handle background/foreground transitions

**Modifications to `Repair_MinderApp`:**

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
            if let backgroundTime = backgroundTime {
                let duration = Date().timeIntervalSince(backgroundTime)
                if passcodeService.shouldLockOnForeground(backgroundDuration: duration) {
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

### 2. Xcode Project — Info.plist / Build Settings

**Add `NSFaceIDUsageDescription`** to the target's Info.plist configuration. This can be done by:

Option A: Add to the `INFOPLIST_KEY` build settings in `project.pbxproj`:
```
INFOPLIST_KEY_NSFaceIDUsageDescription = "Repair Minder uses Face ID to unlock the app securely.";
```

Option B: Add an `Info.plist` file if one exists with:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Repair Minder uses Face ID to unlock the app securely.</string>
```

Check which approach the project currently uses and follow the same pattern.

---

## Database Changes

None.

---

## Test Cases

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 1 | Lock on background return | Enable passcode → Background app 10s → Return | Lock screen appears |
| 2 | No lock within grace period | Enable passcode → Background app 2s → Return | No lock screen |
| 3 | No lock when disabled | Passcode disabled → Background → Return | No lock screen |
| 4 | Unlock with correct PIN | Lock screen → Enter correct PIN | Lock screen dismisses, app visible |
| 5 | Wrong PIN entry | Lock screen → Enter wrong PIN | Shake animation, dots clear, error shown |
| 6 | Multiple wrong PINs | Enter wrong PIN 3x | Each time: shake + clear (no lockout in v1) |
| 7 | Biometric auto-prompt | Lock screen appears (biometric enabled) | Face ID / Touch ID prompt shows automatically |
| 8 | Biometric success | Authenticate with biometric | Lock screen dismisses |
| 9 | Biometric cancel → PIN | Cancel biometric → Enter PIN | Falls back to PIN entry, correct PIN unlocks |
| 10 | Forgot PIN logout | Lock screen → "Forgot Passcode?" → Logout | Passcode removed, user logged out, login screen shown |
| 11 | Lock on first launch | Enable passcode → Force quit app → Relaunch | Lock screen should NOT show (no background event, fresh launch) |
| 12 | Transition animation | Lock/unlock | Smooth opacity transition |
| 13 | Face ID description | Check Info.plist | `NSFaceIDUsageDescription` present |

---

## Acceptance Checklist

- [ ] `PasscodeLockView` displays full-screen over app content
- [ ] Number pad works correctly on lock screen
- [ ] Correct PIN dismisses lock screen
- [ ] Wrong PIN triggers shake and error
- [ ] Biometric button visible only when biometric enabled
- [ ] Biometric auto-prompts on lock screen appear
- [ ] Biometric success unlocks the app
- [ ] "Forgot Passcode?" shows alert with logout option
- [ ] Logout from lock screen clears passcode and shows login
- [ ] `scenePhase` monitoring correctly detects background→active transitions
- [ ] 5-second grace period works (quick switches don't trigger lock)
- [ ] `NSFaceIDUsageDescription` added to project
- [ ] Smooth opacity animation on lock/unlock
- [ ] No lock screen when passcode is disabled
- [ ] Project builds and runs successfully

---

## Deployment

```bash
# Build and run on simulator:
mcp__XcodeBuildMCP__build_run_sim

# Test flow:
# 1. Go to More → Security → Enable Passcode
# 2. Set a PIN (e.g., 123456)
# 3. Press Home (Cmd+Shift+H in simulator)
# 4. Wait 10+ seconds
# 5. Return to app — lock screen should appear
# 6. Enter PIN to unlock
```

---

## Handoff Notes

This is the final stage. After completion:
- Full passcode lock feature is functional
- All files are created and wired together
- Feature is testable end-to-end in the simulator
- Face ID testing requires a physical device (simulator has limited biometric simulation via Features → Face ID menu)
