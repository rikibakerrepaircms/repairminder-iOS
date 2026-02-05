# Stage 05 — iOS: Settings & Reset

## Objective

Add passcode settings screen (change passcode, configure timeout, biometric toggle) and wire the forgot-passcode email reset flow into Settings.

## Dependencies

`[Requires: Stage 02 complete]` — Needs `PasscodeService` API methods.
`[Requires: Stage 03 complete]` — Needs `SetPasscodeView`, `ResetPasscodeView`, `NumberPadView`.
`[Requires: Stage 04 complete]` — Needs app lock working to verify settings changes take effect.

## Complexity

**Low** — Standard settings UI following existing patterns [Ref: Features/Settings/NotificationSettingsView.swift].

---

## Files to Create

### 1. `Features/Settings/Security/PasscodeSettingsView.swift`

**Purpose:** Settings screen for managing passcode, timeout, and biometric preferences.

**Layout:**
```
Section "Passcode"
  Toggle: "Passcode Lock" (enable/disable — requires passcode verification to disable)
  Button: "Change Passcode" (only when enabled)
  Button: "Reset Passcode via Email"

Section "Unlock Method" (only if biometric available)
  Toggle: "Use Face ID" / "Use Touch ID"
    Subtitle: "Unlock with Face ID instead of entering passcode"

Section "Auto-Lock"
  Picker: "Require Passcode"
    Options: 1 min, 5 min, 15 min (default), 30 min, 1 hour
```

```swift
import SwiftUI

struct PasscodeSettingsView: View {
    @StateObject private var viewModel = PasscodeSettingsViewModel()
    @ObservedObject private var passcodeService = PasscodeService.shared

    var body: some View {
        List {
            // Passcode management
            Section("Passcode") {
                Toggle(isOn: Binding(
                    get: { passcodeService.passcodeEnabled },
                    set: { newValue in viewModel.toggleEnabled(newValue) }
                )) {
                    Label("Passcode Lock", systemImage: "lock.fill")
                }

                if passcodeService.passcodeEnabled {
                    Button("Change Passcode") {
                        viewModel.showChangePasscode = true
                    }
                }

                Button("Reset via Email") {
                    viewModel.showResetConfirmation = true
                }
            }

            // Biometric
            if passcodeService.isBiometricAvailable {
                Section {
                    Toggle(isOn: Binding(
                        get: { passcodeService.isBiometricEnabled },
                        set: { passcodeService.setBiometric(enabled: $0) }
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(passcodeService.biometricType.displayName)
                                Text("Unlock with \(passcodeService.biometricType.displayName) instead of passcode")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: passcodeService.biometricType.systemImage)
                        }
                    }
                }
            }

            // Timeout
            Section {
                Picker(selection: $viewModel.selectedTimeout) {
                    ForEach(viewModel.timeoutOptions, id: \.minutes) { option in
                        Text(option.label).tag(option.minutes)
                    }
                } label: {
                    Label("Require Passcode", systemImage: "timer")
                }
                .onChange(of: viewModel.selectedTimeout) { _, newValue in
                    viewModel.updateTimeout(newValue)
                }
            } footer: {
                Text("How long the app can be in the background before requiring the passcode again.")
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showChangePasscode) {
            SetPasscodeView(mode: .change) { _ in }
                .interactiveDismissDisabled()
        }
        .alert("Reset Passcode", isPresented: $viewModel.showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Send Reset Email") {
                viewModel.requestReset()
            }
        } message: {
            Text("We'll send a reset code to your registered email address.")
        }
        .sheet(isPresented: $viewModel.showResetFlow) {
            ResetPasscodeView()
                .interactiveDismissDisabled()
        }
        .alert("Disable Passcode Lock?", isPresented: $viewModel.showDisableConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Disable", role: .destructive) {
                viewModel.confirmDisable()
            }
        } message: {
            Text("Your passcode will be kept but the lock screen will no longer appear.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
```

### 2. `Features/Settings/Security/PasscodeSettingsViewModel.swift`

```swift
import SwiftUI

@MainActor
final class PasscodeSettingsViewModel: ObservableObject {
    @Published var showChangePasscode = false
    @Published var showResetConfirmation = false
    @Published var showResetFlow = false
    @Published var showDisableConfirmation = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var selectedTimeout: Int

    private let passcodeService = PasscodeService.shared

    struct TimeoutOption {
        let minutes: Int
        let label: String
    }

    let timeoutOptions: [TimeoutOption] = [
        TimeoutOption(minutes: 1,  label: "1 minute"),
        TimeoutOption(minutes: 5,  label: "5 minutes"),
        TimeoutOption(minutes: 15, label: "15 minutes"),
        TimeoutOption(minutes: 30, label: "30 minutes"),
        TimeoutOption(minutes: 60, label: "1 hour"),
    ]

    init() {
        selectedTimeout = PasscodeService.shared.timeoutMinutes
    }

    func updateTimeout(_ minutes: Int) {
        Task {
            do {
                try await passcodeService.updateTimeout(minutes)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                // Revert picker
                selectedTimeout = passcodeService.timeoutMinutes
            }
        }
    }

    func toggleEnabled(_ enabled: Bool) {
        if !enabled {
            // Disabling requires confirmation
            showDisableConfirmation = true
            return
        }
        Task {
            do {
                try await passcodeService.togglePasscodeEnabled(true)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    func confirmDisable() {
        Task {
            do {
                try await passcodeService.togglePasscodeEnabled(false)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    func requestReset() {
        Task {
            do {
                try await passcodeService.requestPasscodeReset()
                showResetFlow = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
```

---

## Files to Modify

### `Features/Settings/SettingsView.swift`

**Add Security section** between notifications and about sections.

Add to `body` List after `notificationsSection`:
```swift
// Security section
securitySection
```

Add new computed property:
```swift
// MARK: - Security Section

private var securitySection: some View {
    Section("Security") {
        NavigationLink {
            PasscodeSettingsView()
        } label: {
            Label {
                Text("Passcode & \(PasscodeService.shared.biometricType.displayName)")
            } icon: {
                Image(systemName: "lock.shield")
            }
        }
    }
}
```

---

## Database Changes

None (iOS-side only — timeout synced via API from [See: Stage 01]).

---

## Test Cases

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 1 | Navigate to Security | Settings → "Passcode & Face ID" | Shows PasscodeSettingsView |
| 2 | Change passcode | Tap "Change Passcode" | Sheet with change flow |
| 3 | Biometric toggle ON | Toggle Face ID on | `isBiometricEnabled` becomes true |
| 4 | Biometric toggle OFF | Toggle Face ID off | `isBiometricEnabled` becomes false |
| 5 | Biometric hidden on simulator | No biometric available | Section not shown |
| 6 | Change timeout to 5 min | Pick "5 minutes" | API called, local state updated |
| 7 | Change timeout — API error | Network off + change | Error alert, reverts to previous |
| 8 | Timeout affects lock | Set 1 min → background 2 min → return (with passcode enabled) | Lock screen shown |
| 9 | Request reset email | Tap "Reset via Email" → confirm | Email sent, reset sheet shown |
| 10 | Reset flow from settings | Enter code → new PIN → confirm | Passcode updated |
| 11 | Security label | Device with Face ID | Shows "Passcode & Face ID" |
| 12 | Security label | Device with Touch ID | Shows "Passcode & Touch ID" |
| 13 | Security label | Simulator | Shows "Passcode & Biometric" |
| 14 | Disable passcode lock | Toggle OFF → confirm | `passcodeEnabled = false`, no more lock screen |
| 15 | Re-enable passcode lock | Toggle ON | `passcodeEnabled = true`, lock screen resumes |
| 16 | Disable doesn't delete hash | Toggle OFF → toggle ON → lock → enter PIN | Still works with same PIN |

---

## Acceptance Checklist

- [ ] Passcode Lock toggle enables/disables via API
- [ ] Disable shows confirmation alert
- [ ] Disabling keeps passcode hash (doesn't delete)
- [ ] Security section visible in SettingsView
- [ ] NavigationLink navigates to PasscodeSettingsView
- [ ] "Change Passcode" opens SetPasscodeView in `.change` mode
- [ ] "Reset via Email" sends API request and shows ResetPasscodeView
- [ ] Biometric toggle only visible when biometric hardware available
- [ ] Biometric toggle persists across app restarts (Keychain)
- [ ] Timeout picker shows all options
- [ ] Timeout change syncs to backend via API
- [ ] Timeout change takes effect immediately for lock behavior
- [ ] Error handling works for API failures
- [ ] Sheets use `.interactiveDismissDisabled()`
- [ ] Project builds and runs successfully

---

## Deployment & Simulator Verification

```bash
# Build and run on simulator:
mcp__XcodeBuildMCP__build_run_sim
# Project: /Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj
# Simulator: iPhone 16 Pro

# Login with test account:
# 1. Request magic link for rikibaker+admin@gmail.com in the app
# 2. Get code from D1:
cd "/Volumes/Riki Repos/repairminder" && npx wrangler d1 execute repairminder_database --remote --json --command "SELECT magic_link_code FROM users WHERE email = 'rikibaker+admin@gmail.com'" 2>/dev/null | jq -r '.[0].results[0].magic_link_code'
# 3. Enter code in app to login

# Verify settings:
# 1. Navigate to More tab → Security
# 2. Verify "Change Passcode" works (enter current → new → confirm)
# 3. Verify biometric toggle (may show as unavailable on simulator — that's OK)
# 4. Verify timeout picker changes (select 1 min, then test lock behavior)
# 5. Verify "Reset via Email" sends email and shows reset flow
# 6. Verify passcode lock can be DISABLED from settings (toggle OFF → confirm → no more lock)
# 7. Take screenshot of the Security settings screen
```

---

## Handoff Notes

This is the final stage. After completion:
- Full passcode feature is functional end-to-end
- Backend endpoints support the feature [See: Stage 01]
- iOS caches passcode hash locally for fast offline verification [See: Stage 02]
- First-login forces passcode creation [See: Stage 04]
- Settings allow full management (change, reset, timeout, biometric)
- Web dashboard can use the same API endpoints to add passcode settings later (out of scope)
