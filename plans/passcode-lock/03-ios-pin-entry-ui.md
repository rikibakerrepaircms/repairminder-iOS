# Stage 03 — iOS: PIN Entry UI

## Objective

Build the reusable `NumberPadView`, `SetPasscodeView` (create/change flow), and `PasscodeLockView` (unlock screen) components.

## Dependencies

`[Requires: Stage 02 complete]` — Needs `PasscodeService` for verification and API calls.

## Complexity

**Medium** — Custom number pad, multi-step flow, shake animation, biometric prompt.

---

## Files to Create

### 1. `Features/Settings/Security/NumberPadView.swift`

**Purpose:** Reusable 3x4 grid number pad (1-9, empty, 0, delete). Used by `SetPasscodeView`, `PasscodeLockView`, and `DisablePasscodeSheet`.

```swift
import SwiftUI

struct NumberPadView: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    private let buttons: [[NumberPadButton]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.empty,      .digit("0"), .delete]
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(buttons.indices, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(buttons[row].indices, id: \.self) { col in
                        numberPadButton(buttons[row][col])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func numberPadButton(_ button: NumberPadButton) -> some View {
        switch button {
        case .digit(let d):
            Button(action: { onDigit(d) }) {
                Text(d)
                    .font(.system(size: 28, weight: .medium))
                    .frame(width: 72, height: 72)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        case .delete:
            Button(action: onDelete) {
                Image(systemName: "delete.left")
                    .font(.system(size: 22))
                    .frame(width: 72, height: 72)
            }
            .buttonStyle(.plain)
        case .empty:
            Color.clear.frame(width: 72, height: 72)
        }
    }

    private enum NumberPadButton {
        case digit(String), delete, empty
    }
}

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var animatableData: CGFloat

    init(shakes: Int) {
        self.shakes = shakes
        self.animatableData = CGFloat(shakes)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(animatableData * .pi * 2) * 10
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - PIN Dots

struct PINDotsView: View {
    let enteredCount: Int
    let totalCount: Int
    var shakeCount: Int = 0

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<totalCount, id: \.self) { index in
                Circle()
                    .fill(index < enteredCount ? Color.accentColor : Color(.systemGray4))
                    .frame(width: 14, height: 14)
            }
        }
        .modifier(ShakeEffect(shakes: shakeCount))
        .animation(.default, value: shakeCount)
    }
}
```

### 2. `Features/Settings/Security/SetPasscodeView.swift`

**Purpose:** Presented as sheet for creating or changing passcodes. Talks to backend via `PasscodeService`.

**Flow:**
```
Mode: .create
  Step 1: "Create a passcode" → 6 digits
  Step 2: "Confirm passcode" → re-enter
    Match → POST /api/auth/set-passcode → dismiss
    Mismatch → shake → back to Step 1

Mode: .change
  Step 1: "Enter current passcode" → verify locally
    Wrong → shake → retry
    Right → proceed
  Step 2: "Enter new passcode" → 6 digits
  Step 3: "Confirm new passcode" → re-enter
    Match → POST /api/auth/change-passcode → dismiss
    Mismatch → shake → back to Step 2
```

```swift
import SwiftUI

struct SetPasscodeView: View {
    enum Mode { case create, change }

    let mode: Mode
    let onComplete: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step
    @State private var currentInput: String = ""
    @State private var firstEntry: String = ""
    @State private var verifiedCurrentPasscode: String = ""  // Stores current passcode for change-passcode API
    @State private var errorMessage: String?
    @State private var shakeCount: Int = 0
    @State private var isLoading: Bool = false

    private let passcodeLength = 6
    private let passcodeService = PasscodeService.shared

    enum Step: String {
        case enterCurrent = "Enter current passcode"
        case enterNew = "Create a passcode"
        case confirmNew = "Confirm passcode"
    }

    init(mode: Mode, onComplete: @escaping (Bool) -> Void) {
        self.mode = mode
        self.onComplete = onComplete
        _step = State(initialValue: mode == .change ? .enterCurrent : .enterNew)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(step.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)

                PINDotsView(
                    enteredCount: currentInput.count,
                    totalCount: passcodeLength,
                    shakeCount: shakeCount
                )

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if isLoading {
                    ProgressView()
                } else {
                    NumberPadView(
                        onDigit: appendDigit,
                        onDelete: deleteDigit
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle(mode == .create ? "Set Passcode" : "Change Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(false)
                        dismiss()
                    }
                }
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard currentInput.count < passcodeLength, !isLoading else { return }
        currentInput += digit
        errorMessage = nil
        if currentInput.count == passcodeLength {
            handleCompleteEntry()
        }
    }

    private func deleteDigit() {
        guard !currentInput.isEmpty, !isLoading else { return }
        currentInput.removeLast()
    }

    private func handleCompleteEntry() {
        switch step {
        case .enterCurrent:
            if passcodeService.verifyPasscode(currentInput) {
                verifiedCurrentPasscode = currentInput  // Save for API call
                currentInput = ""
                step = .enterNew
            } else {
                triggerError("Incorrect passcode")
            }

        case .enterNew:
            firstEntry = currentInput
            currentInput = ""
            step = .confirmNew

        case .confirmNew:
            if currentInput == firstEntry {
                savePasscode()
            } else {
                firstEntry = ""
                triggerError("Passcodes don't match. Try again.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    step = .enterNew
                }
            }
        }
    }

    private func savePasscode() {
        isLoading = true
        Task {
            do {
                if mode == .create {
                    try await passcodeService.setPasscode(currentInput)
                } else {
                    try await passcodeService.changePasscode(
                        current: verifiedCurrentPasscode,
                        new: currentInput
                    )
                }
                onComplete(true)
                dismiss()
            } catch {
                triggerError(error.localizedDescription)
                isLoading = false
            }
        }
    }

    private func triggerError(_ message: String) {
        errorMessage = message
        currentInput = ""
        withAnimation { shakeCount += 1 }
    }
}
```

**Note on change mode:** The `enterCurrent` step verifies locally and stores the verified passcode in `verifiedCurrentPasscode` so it can be sent to the change-passcode API.

### 3. `Features/Settings/Security/PasscodeLockView.swift`

**Purpose:** Full-screen lock overlay with PIN entry, biometric, and forgot-passcode option.

```swift
import SwiftUI

struct PasscodeLockView: View {
    @StateObject private var viewModel = PasscodeLockViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.accentColor)

                Text("Enter Passcode")
                    .font(.title2)
                    .fontWeight(.semibold)

                PINDotsView(
                    enteredCount: viewModel.enteredDigits.count,
                    totalCount: viewModel.passcodeLength,
                    shakeCount: viewModel.shakeCount
                )

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                NumberPadView(
                    onDigit: { viewModel.appendDigit($0) },
                    onDelete: { viewModel.deleteDigit() }
                )

                if viewModel.canUseBiometric {
                    Button(action: { viewModel.authenticateWithBiometric() }) {
                        Image(systemName: viewModel.biometricIcon)
                            .font(.system(size: 36))
                            .foregroundStyle(.accentColor)
                    }
                    .disabled(viewModel.isAuthenticating)
                    .padding(.top, 4)
                }

                Button("Forgot Passcode?") {
                    viewModel.showForgotAlert = true
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
        }
        .alert("Forgot Passcode?", isPresented: $viewModel.showForgotAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Send Reset Email", role: .destructive) {
                viewModel.requestPasscodeReset()
            }
            Button("Logout", role: .destructive) {
                viewModel.forceLogout()
            }
        } message: {
            Text("We can send a reset code to your email, or you can logout and sign in again.")
        }
        .sheet(isPresented: $viewModel.showResetFlow) {
            ResetPasscodeView()
        }
        .onAppear {
            viewModel.attemptBiometricOnAppear()
        }
    }
}
```

### 4. `Features/Settings/Security/PasscodeLockViewModel.swift`

```swift
import SwiftUI

@MainActor
final class PasscodeLockViewModel: ObservableObject {
    @Published var enteredDigits: String = ""
    @Published var shakeCount: Int = 0
    @Published var showForgotAlert: Bool = false
    @Published var showResetFlow: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var errorMessage: String?

    let passcodeLength = 6
    private let passcodeService = PasscodeService.shared

    var canUseBiometric: Bool {
        passcodeService.isBiometricEnabled && passcodeService.isBiometricAvailable
    }
    var biometricIcon: String { passcodeService.biometricType.systemImage }

    func appendDigit(_ digit: String) {
        guard enteredDigits.count < passcodeLength else { return }
        enteredDigits += digit
        errorMessage = nil
        if enteredDigits.count == passcodeLength { verifyPasscode() }
    }

    func deleteDigit() {
        guard !enteredDigits.isEmpty else { return }
        enteredDigits.removeLast()
    }

    private func verifyPasscode() {
        if passcodeService.verifyPasscode(enteredDigits) {
            passcodeService.unlockApp()
        } else {
            enteredDigits = ""
            errorMessage = "Incorrect passcode"
            withAnimation { shakeCount += 1 }
        }
    }

    func attemptBiometricOnAppear() {
        guard canUseBiometric, !isAuthenticating else { return }
        authenticateWithBiometric()
    }

    func authenticateWithBiometric() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            let result = await passcodeService.authenticateWithBiometric()
            isAuthenticating = false
            switch result {
            case .success: passcodeService.unlockApp()
            case .failure(.biometricCancelled): break
            case .failure(let error): errorMessage = error.errorDescription
            }
        }
    }

    func requestPasscodeReset() {
        Task {
            do {
                try await passcodeService.requestPasscodeReset()
                showResetFlow = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func forceLogout() {
        passcodeService.clearLocalData()
        Task {
            if AuthManager.shared.authState == .authenticated {
                await AuthManager.shared.logout()
                AppState.shared.onStaffLogout()
            } else {
                await AppState.shared.fullLogout()
            }
        }
    }
}
```

### 5. `Features/Settings/Security/ResetPasscodeView.swift`

**Purpose:** After "Forgot Passcode?" sends email, this view lets user enter the reset code and set a new passcode.

```swift
import SwiftUI

struct ResetPasscodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .enterCode
    @State private var resetCode: String = ""
    @State private var newPasscode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var errorMessage: String?
    @State private var shakeCount: Int = 0
    @State private var isLoading: Bool = false

    private let passcodeLength = 6
    private let passcodeService = PasscodeService.shared

    enum Step: String {
        case enterCode = "Enter reset code from email"
        case enterNew = "Enter new passcode"
        case confirmNew = "Confirm new passcode"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(step.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)

                PINDotsView(
                    enteredCount: currentInput.count,
                    totalCount: passcodeLength,
                    shakeCount: shakeCount
                )

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if isLoading {
                    ProgressView()
                } else {
                    NumberPadView(
                        onDigit: { digit in appendDigit(digit) },
                        onDelete: { deleteDigit() }
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Reset Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var currentInput: String {
        switch step {
        case .enterCode: return resetCode
        case .enterNew: return newPasscode
        case .confirmNew: return confirmPasscode
        }
    }

    private func appendDigit(_ digit: String) {
        guard currentInput.count < passcodeLength, !isLoading else { return }
        switch step {
        case .enterCode: resetCode += digit
        case .enterNew: newPasscode += digit
        case .confirmNew: confirmPasscode += digit
        }
        errorMessage = nil
        if currentInput.count == passcodeLength { handleComplete() }
    }

    private func deleteDigit() {
        guard !currentInput.isEmpty, !isLoading else { return }
        switch step {
        case .enterCode: resetCode.removeLast()
        case .enterNew: newPasscode.removeLast()
        case .confirmNew: confirmPasscode.removeLast()
        }
    }

    private func handleComplete() {
        switch step {
        case .enterCode:
            step = .enterNew

        case .enterNew:
            step = .confirmNew

        case .confirmNew:
            if confirmPasscode == newPasscode {
                submitReset()
            } else {
                newPasscode = ""
                confirmPasscode = ""
                triggerError("Passcodes don't match")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    step = .enterNew
                }
            }
        }
    }

    private func submitReset() {
        isLoading = true
        Task {
            do {
                try await passcodeService.resetPasscode(code: resetCode, newPasscode: newPasscode)
                passcodeService.unlockApp()
                dismiss()
            } catch {
                triggerError(error.localizedDescription)
                isLoading = false
            }
        }
    }

    private func triggerError(_ message: String) {
        errorMessage = message
        confirmPasscode = ""
        withAnimation { shakeCount += 1 }
    }
}
```

---

## Files to Modify

None.

---

## Database Changes

None.

---

## Test Cases

| # | Scenario | Expected |
|---|----------|----------|
| 1 | NumberPad digits 0-9 | Each digit triggers callback |
| 2 | NumberPad delete | Removes last digit |
| 3 | Create passcode — matching confirmation | API called, sheet dismisses |
| 4 | Create passcode — mismatch | Shake, error, back to step 1 |
| 5 | Change passcode — wrong current | Shake, error, stays on current step |
| 6 | Change passcode — full flow | Verify current → enter new → confirm → API |
| 7 | Lock screen — correct PIN | Unlocks app |
| 8 | Lock screen — wrong PIN | Shake, clear, error |
| 9 | Lock screen — biometric auto-prompt | Face ID shows on appear |
| 10 | Lock screen — biometric cancel | Falls back to PIN entry |
| 11 | Forgot passcode — send email | API called, reset sheet appears |
| 12 | Forgot passcode — logout | Clears data, returns to login |
| 13 | Reset flow — full | Code → new PIN → confirm → API → unlock |
| 14 | PIN dots fill correctly | Dots animate as digits entered |
| 15 | API error during save | Error message shown, not dismissed |

---

## Acceptance Checklist

- [ ] `NumberPadView` displays 3x4 grid with proper sizing
- [ ] `PINDotsView` correctly shows filled/empty states
- [ ] `ShakeEffect` animates on error
- [ ] `SetPasscodeView` handles `.create` and `.change` modes
- [ ] `SetPasscodeView` calls `PasscodeService` API methods
- [ ] `PasscodeLockView` fills entire screen
- [ ] Biometric button shows only when enabled + available
- [ ] "Forgot Passcode?" shows alert with reset email and logout options
- [ ] `ResetPasscodeView` handles full code → new PIN → confirm flow
- [ ] Loading states shown during API calls
- [ ] Project builds successfully

---

## Deployment & Verification

```bash
# Build on simulator to verify compilation:
mcp__XcodeBuildMCP__build_sim
# Project: /Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj

# These views are not yet wired into the app navigation — that happens in [See: Stage 04].
# At this stage, verify:
# 1. Project builds with zero errors
# 2. New files are added to the Xcode project correctly
# 3. Preview the views in Xcode Canvas if possible (Cmd+Option+P)
```

---

## Handoff Notes

- `NumberPadView`, `PINDotsView`, and `ShakeEffect` are shared components used in multiple places
- `SetPasscodeView` is used for first-login setup in [See: Stage 04] and settings change in [See: Stage 05]
- `PasscodeLockView` is overlaid on the app in [See: Stage 04]
- `ResetPasscodeView` is presented from both the lock screen and settings in [See: Stage 05]
