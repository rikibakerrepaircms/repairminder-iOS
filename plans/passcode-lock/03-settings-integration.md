# Stage 03 — Settings Integration

## Objective

Create `PasscodeSettingsView` with toggles for passcode enable/disable and biometric enable/disable, and wire it into the existing `SettingsView` as a new "Security" section.

## Dependencies

`[Requires: Stage 01 complete]` — Needs `PasscodeService` for state and biometric info.
`[Requires: Stage 02 complete]` — Needs `SetPasscodeView` for create/change sheets.

## Complexity

**Low** — Standard SwiftUI list with toggles, following existing patterns from `NotificationSettingsView` [Ref: Features/Settings/NotificationSettingsView.swift].

---

## Files to Create

### 1. `Features/Settings/Security/PasscodeSettingsViewModel.swift`

**Purpose:** View model managing passcode settings state and toggle interactions.

```swift
import SwiftUI

@MainActor
final class PasscodeSettingsViewModel: ObservableObject {
    @Published var showSetPasscode = false
    @Published var showChangePasscode = false
    @Published var showDisableConfirmation = false
    @Published var showDisablePasscodeEntry = false
    @Published var disableError: String?

    private let passcodeService = PasscodeService.shared

    var isPasscodeEnabled: Bool { passcodeService.isPasscodeEnabled }
    var isBiometricEnabled: Bool { passcodeService.isBiometricEnabled }
    var isBiometricAvailable: Bool { passcodeService.isBiometricAvailable }
    var biometricName: String { passcodeService.biometricType.displayName }
    var biometricIcon: String { passcodeService.biometricType.systemImage }

    func handlePasscodeToggle(_ enabled: Bool) {
        if enabled {
            showSetPasscode = true
        } else {
            // Need to verify current passcode before disabling
            showDisablePasscodeEntry = true
        }
    }

    func handlePasscodeCreated(_ success: Bool) {
        // If creation was cancelled, state reverts automatically
        // If successful, passcode is already saved by SetPasscodeView
    }

    func handleDisablePasscode(_ passcode: String) -> Bool {
        if passcodeService.verifyPasscode(passcode) {
            passcodeService.removePasscode()
            disableError = nil
            return true
        } else {
            disableError = "Incorrect passcode"
            return false
        }
    }

    func toggleBiometric(_ enabled: Bool) {
        passcodeService.setBiometric(enabled: enabled)
    }
}
```

### 2. `Features/Settings/Security/PasscodeSettingsView.swift`

**Purpose:** Settings screen for managing passcode and biometric preferences.

**Layout:**
```
Section "Passcode"
  Toggle: Passcode Lock (on/off)
    Subtitle: "Require passcode to unlock app"

Section "Biometric" (only if passcode enabled AND biometric available)
  Toggle: Use Face ID / Touch ID (on/off)
    Subtitle: "Unlock with Face ID instead of passcode"

Section (only if passcode enabled)
  Button: Change Passcode
```

```swift
import SwiftUI

struct PasscodeSettingsView: View {
    @StateObject private var viewModel = PasscodeSettingsViewModel()
    @ObservedObject private var passcodeService = PasscodeService.shared

    var body: some View {
        List {
            // Passcode toggle section
            Section {
                Toggle(isOn: Binding(
                    get: { passcodeService.isPasscodeEnabled },
                    set: { viewModel.handlePasscodeToggle($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Passcode Lock")
                        Text("Require passcode to unlock app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Biometric section
            if passcodeService.isPasscodeEnabled && viewModel.isBiometricAvailable {
                Section {
                    Toggle(isOn: Binding(
                        get: { passcodeService.isBiometricEnabled },
                        set: { viewModel.toggleBiometric($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(viewModel.biometricName, systemImage: viewModel.biometricIcon)
                            Text("Unlock with \(viewModel.biometricName) instead of passcode")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Change passcode
            if passcodeService.isPasscodeEnabled {
                Section {
                    Button("Change Passcode") {
                        viewModel.showChangePasscode = true
                    }
                }
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showSetPasscode) {
            SetPasscodeView(mode: .create) { success in
                viewModel.handlePasscodeCreated(success)
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $viewModel.showChangePasscode) {
            SetPasscodeView(mode: .change) { _ in }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $viewModel.showDisablePasscodeEntry) {
            DisablePasscodeSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Disable Passcode Sheet

/// Small sheet that asks user to enter current passcode to disable it
private struct DisablePasscodeSheet: View {
    @ObservedObject var viewModel: PasscodeSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var input: String = ""
    @State private var shakeCount: Int = 0

    private let passcodeLength = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text("Enter passcode to disable")
                    .font(.title3)
                    .fontWeight(.semibold)

                HStack(spacing: 16) {
                    ForEach(0..<passcodeLength, id: \.self) { index in
                        Circle()
                            .fill(index < input.count ? Color.accentColor : Color(.systemGray4))
                            .frame(width: 14, height: 14)
                    }
                }
                .modifier(ShakeEffect(shakes: shakeCount))
                .animation(.default, value: shakeCount)

                if let error = viewModel.disableError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                NumberPadView(
                    onDigit: { digit in
                        guard input.count < passcodeLength else { return }
                        input += digit
                        if input.count == passcodeLength {
                            if viewModel.handleDisablePasscode(input) {
                                dismiss()
                            } else {
                                input = ""
                                withAnimation { shakeCount += 1 }
                            }
                        }
                    },
                    onDelete: {
                        guard !input.isEmpty else { return }
                        input.removeLast()
                    }
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Disable Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
```

---

## Files to Modify

### `Features/Settings/SettingsView.swift`

**Changes:** Add a Security section with NavigationLink to `PasscodeSettingsView`, placed between the notifications section and the about section.

**Before (line ~30):**
```swift
// Notifications section
notificationsSection

// About section
aboutSection
```

**After:**
```swift
// Notifications section
notificationsSection

// Security section
securitySection

// About section
aboutSection
```

**Add new computed property:**
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

None.

---

## Test Cases

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 1 | Navigate to Security | Settings → tap "Passcode & Face ID" | Shows PasscodeSettingsView |
| 2 | Enable passcode | Toggle ON | Presents SetPasscodeView sheet |
| 3 | Cancel enable | Toggle ON → Cancel sheet | Toggle stays OFF |
| 4 | Successful enable | Toggle ON → Set PIN → Confirm | Toggle stays ON, biometric section appears |
| 5 | Enable biometric | Toggle Face ID ON | Toggle stays ON |
| 6 | Disable biometric | Toggle Face ID OFF | Toggle stays OFF |
| 7 | Change passcode | Tap "Change Passcode" | Presents SetPasscodeView in change mode |
| 8 | Disable passcode — correct PIN | Toggle OFF → Enter correct PIN | Toggle goes OFF, biometric section disappears |
| 9 | Disable passcode — wrong PIN | Toggle OFF → Enter wrong PIN | Shake, error, stays enabled |
| 10 | Biometric hidden when unavailable | Simulator (no biometric) | Biometric section not visible |
| 11 | Security label shows correct biometric | Device with Face ID | Label says "Passcode & Face ID" |

---

## Acceptance Checklist

- [ ] Security section visible in SettingsView
- [ ] NavigationLink navigates to PasscodeSettingsView
- [ ] Passcode toggle shows SetPasscodeView on enable
- [ ] Passcode toggle shows DisablePasscodeSheet on disable
- [ ] Biometric toggle only visible when passcode enabled AND biometric available
- [ ] "Change Passcode" button only visible when passcode enabled
- [ ] Sheets use `.interactiveDismissDisabled()` to prevent swipe-dismiss during PIN entry
- [ ] Settings label dynamically shows "Face ID" or "Touch ID" or "Biometric"
- [ ] Project builds successfully

---

## Deployment

```bash
# Build and run to test settings navigation:
mcp__XcodeBuildMCP__build_run_sim
```

Navigate to More tab → Security to verify the UI.

---

## Handoff Notes

- `PasscodeSettingsView` is fully functional and connected to `PasscodeService`
- The lock screen overlay in [See: Stage 04] is the final piece — without it, enabling a passcode has no visible effect outside Settings
- The `DisablePasscodeSheet` reuses `NumberPadView` and `ShakeEffect` from [See: Stage 02]
