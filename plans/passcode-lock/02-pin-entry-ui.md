# Stage 02 — PIN Entry UI

## Objective

Build the reusable `NumberPadView` component and `SetPasscodeView` flow for creating and changing 6-digit passcodes.

## Dependencies

`[Requires: Stage 01 complete]` — Needs `PasscodeService` for `setPasscode()` and `verifyPasscode()`.

## Complexity

**Medium** — Custom number pad layout, multi-step flow (enter → confirm), shake animation.

---

## Files to Create

### 1. `Features/Settings/Security/NumberPadView.swift`

**Purpose:** Reusable 3×4 grid number pad (1-9, empty, 0, delete) used by both `SetPasscodeView` and `PasscodeLockView`.

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
            Color.clear
                .frame(width: 72, height: 72)
        }
    }

    private enum NumberPadButton {
        case digit(String)
        case delete
        case empty
    }
}
```

### 2. `Features/Settings/Security/SetPasscodeView.swift`

**Purpose:** Presented as a sheet for creating or changing the passcode. Multi-step flow with visual PIN dots and shake animation on error.

**Flow:**

```
Mode: .create
  Step 1: "Enter a passcode" → user enters 6 digits
  Step 2: "Confirm passcode" → user re-enters same 6 digits
    Match → save to PasscodeService, dismiss with success
    Mismatch → shake, clear, return to Step 1

Mode: .change
  Step 1: "Enter current passcode" → verify against stored
    Wrong → shake, clear, retry
    Correct → proceed
  Step 2: "Enter new passcode" → user enters 6 digits
  Step 3: "Confirm new passcode" → user re-enters
    Match → save, dismiss
    Mismatch → shake, clear, return to Step 2
```

**Implementation:**

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
    @State private var errorMessage: String?
    @State private var shakeCount: Int = 0

    private let passcodeLength = 6
    private let passcodeService = PasscodeService.shared

    enum Step {
        case enterCurrent
        case enterNew
        case confirmNew
    }

    init(mode: Mode, onComplete: @escaping (Bool) -> Void) {
        self.mode = mode
        self.onComplete = onComplete
        _step = State(initialValue: mode == .change ? .enterCurrent : .enterNew)
    }

    var promptText: String {
        switch step {
        case .enterCurrent: return "Enter current passcode"
        case .enterNew:     return "Enter a passcode"
        case .confirmNew:   return "Confirm passcode"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(promptText)
                    .font(.title2)
                    .fontWeight(.semibold)

                // PIN dots
                HStack(spacing: 16) {
                    ForEach(0..<passcodeLength, id: \.self) { index in
                        Circle()
                            .fill(index < currentInput.count ? Color.accentColor : Color(.systemGray4))
                            .frame(width: 14, height: 14)
                    }
                }
                .modifier(ShakeEffect(shakes: shakeCount))
                .animation(.default, value: shakeCount)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                NumberPadView(
                    onDigit: { digit in appendDigit(digit) },
                    onDelete: { deleteDigit() }
                )

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
        guard currentInput.count < passcodeLength else { return }
        currentInput += digit
        errorMessage = nil

        if currentInput.count == passcodeLength {
            handleCompleteEntry()
        }
    }

    private func deleteDigit() {
        guard !currentInput.isEmpty else { return }
        currentInput.removeLast()
    }

    private func handleCompleteEntry() {
        switch step {
        case .enterCurrent:
            if passcodeService.verifyPasscode(currentInput) {
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
                passcodeService.setPasscode(currentInput)
                onComplete(true)
                dismiss()
            } else {
                firstEntry = ""
                triggerError("Passcodes don't match. Try again.")
                // After shake animation, go back to enterNew
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    step = .enterNew
                }
            }
        }
    }

    private func triggerError(_ message: String) {
        errorMessage = message
        currentInput = ""
        withAnimation {
            shakeCount += 1
        }
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
```

---

## Files to Modify

None.

---

## Database Changes

None.

---

## Test Cases

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 1 | Create passcode — success | Enter 123456 → Confirm 123456 | Sheet dismisses, `onComplete(true)` called |
| 2 | Create passcode — mismatch | Enter 123456 → Confirm 654321 | Shake animation, error "Passcodes don't match", returns to Step 1 |
| 3 | Create passcode — cancel | Tap Cancel | Sheet dismisses, `onComplete(false)` called |
| 4 | Change passcode — correct current | Enter current PIN → New → Confirm | Success |
| 5 | Change passcode — wrong current | Enter wrong PIN | Shake, error "Incorrect passcode", stays on Step 1 |
| 6 | Number pad digits | Tap 1-9, 0 | Digits appear as filled dots |
| 7 | Number pad delete | Tap delete | Last dot unfills |
| 8 | Number pad — max digits | Enter 6 digits | Auto-submits, no 7th digit accepted |
| 9 | Shake animation | Wrong input | Dots shake horizontally |

---

## Acceptance Checklist

- [ ] `NumberPadView` displays 3×4 grid (1-9, empty, 0, delete)
- [ ] Number pad buttons have proper tap targets (72×72pt)
- [ ] `SetPasscodeView` supports `.create` and `.change` modes
- [ ] PIN dots fill as digits are entered
- [ ] Auto-submits when 6 digits reached
- [ ] Mismatch shows shake animation and error text
- [ ] Cancel button dismisses sheet
- [ ] `ShakeEffect` animates smoothly
- [ ] Project builds successfully

---

## Deployment

```bash
# Build to verify compilation:
mcp__XcodeBuildMCP__build_sim
```

These views are not yet wired into the app — they'll be connected in [See: Stage 03].

---

## Handoff Notes

- `NumberPadView` is reused by `PasscodeLockView` in [See: Stage 04]
- `SetPasscodeView` is presented as a `.sheet()` from `PasscodeSettingsView` in [See: Stage 03]
- `ShakeEffect` modifier is reused by `PasscodeLockView` in [See: Stage 04]
- The `onComplete: (Bool) -> Void` callback pattern lets the parent view react to success/cancel
